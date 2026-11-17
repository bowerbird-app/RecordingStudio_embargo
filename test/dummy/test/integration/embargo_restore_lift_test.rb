# frozen_string_literal: true

require "test_helper"
require "active_job/test_helper"
require "recording_studio_trashable"
require "recording_studio_trashable/recording_filter"

# The dummy schema has trashed_at from core. Trashable restore also writes
# trash_root and purge_at. Add those columns for this file only.
module EmbargoRestoreLiftColumns
  def self.ensure!
    recording = RecordingStudio::Recording
    connection = recording.connection
    changed = false

    unless connection.column_exists?(recording.table_name, :trash_root)
      connection.add_column recording.table_name, :trash_root, :boolean, default: false, null: false
      changed = true
    end
    unless connection.column_exists?(recording.table_name, :purge_at)
      connection.add_column recording.table_name, :purge_at, :datetime
      changed = true
    end
    recording.reset_column_information if changed
  end
end

EmbargoRestoreLiftColumns.ensure!

class EmbargoRestoreLiftTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    RecordingStudio.enable_capability(:trashable, on: Page)
    RecordingStudioTrashable::RecordingFilter.register!
    @owner = create_user("owner")
    @editor = create_user("editor")
    workspace = Workspace.create!(name: "Restore #{SecureRandom.hex(4)}")
    @root = RecordingStudio.create_root_recording!(workspace, actor: @owner)
    @page = @root.record(Page, actor: @owner, parent_recording: @root) do |page|
      page.title = "Restored page #{SecureRandom.hex(4)}"
    end
    RecordingStudioAccessible.bootstrap_owner_access!(recording: @root, actor: @owner)
    grant(@editor, :edit)
  end

  teardown do
    ActiveJob::Base.queue_adapter = @previous_adapter
    Current.actor = nil
  end

  test "a lift that comes due while trashed is recorded once after restore" do
    lifts_at = 1.hour.from_now.change(usec: 0)
    activate!(lifts_at: lifts_at)
    trash_page!

    travel_to(lifts_at) do
      RecordingStudioEmbargo::LiftTransitionJob.perform_now(@page.id.to_s, lifts_at.iso8601(6))
      assert_empty lift_events

      notices = capture_lift_notices { restore_page! }
      assert_equal 1, lift_events.count
      assert_equal [@page.id], notices.map { |event| event.payload[:recording_id] }
      assert_equal ["scheduled"], notices.map { |event| event.payload[:source] }
      assert_equal 1, notices.size

      trash_page!
      restore_page!
    end

    assert_equal 1, lift_events.count
    assert lift_events.sole.idempotency_key.start_with?("embargo-lifted-")
  end

  test "restore before lifts_at schedules the job and it fires at lifts_at" do
    lifts_at = 3.hours.from_now.change(usec: 0)
    activate!(lifts_at: lifts_at)
    stored = @page.current_embargo.lifts_at
    trash_page!
    clear_enqueued_jobs

    restore_page!

    assert_enqueued_with(
      job: RecordingStudioEmbargo::LiftTransitionJob,
      args: [@page.id.to_s, stored.iso8601(6)]
    )
    travel_to(stored) { perform_enqueued_jobs }
    assert_equal 1, lift_events.count
  end

  test "restore does not record a second lift when that lifts_at already fired" do
    lifts_at = 1.hour.from_now.change(usec: 0)
    activate!(lifts_at: lifts_at)
    travel_to(lifts_at) do
      RecordingStudioEmbargo::LiftTransitionJob.perform_now(@page.id.to_s, lifts_at.iso8601(6))
    end
    assert_equal 1, lift_events.count

    trash_page!
    travel_to(lifts_at + 5.minutes) { restore_page! }

    assert_equal 1, lift_events.count
  end

  test "restore does not lift a cancelled embargo" do
    lifts_at = 1.hour.from_now.change(usec: 0)
    activate!(lifts_at: lifts_at)
    @page.embargo_cancel!(actor: @owner)
    trash_page!
    clear_enqueued_jobs

    travel_to(lifts_at + 1.minute) { restore_page! }

    assert_empty lift_events
    assert_no_enqueued_jobs only: RecordingStudioEmbargo::LiftTransitionJob
  end

  test "restore does not lift a rescheduled instant" do
    first_lift = 1.hour.from_now.change(usec: 0)
    second_lift = 5.hours.from_now.change(usec: 0)
    activate!(lifts_at: first_lift)
    @page.embargo_set!({ lifts_at: second_lift }, actor: @owner)
    stored = @page.reload.current_embargo.lifts_at
    trash_page!
    clear_enqueued_jobs

    travel_to(first_lift) { restore_page! }

    assert_empty lift_events
    assert_enqueued_with(
      job: RecordingStudioEmbargo::LiftTransitionJob,
      args: [@page.id.to_s, stored.iso8601(6)]
    )
  end

  private

  def create_user(prefix)
    User.create!(
      email: "#{prefix}-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
  end

  def grant(user, role)
    result = RecordingStudioAccessible.grant_access(
      recording: @root,
      actor: user,
      role: role,
      manager_actor: @owner
    )
    raise result.error if result.failure?
  end

  def activate!(lifts_at:)
    @page.embargo_set!(
      {
        enabled: true,
        lifts_at: lifts_at,
        time_zone: "UTC",
        accepts_early_access_requests: false
      },
      actor: @owner
    )
  end

  def trash_page!
    @page.recording_studio_trashable_trash!(actor: @editor)
  end

  def restore_page!
    @page.recording_studio_trashable_restore!(actor: @editor)
  end

  def lift_events
    recording_ids = @page.child_recordings.of_type(RecordingStudioEmbargo::Embargo).select(:id)
    RecordingStudio::Event.where(recording_id: recording_ids, action: "embargo_lifted")
  end

  def capture_lift_notices
    notices = []
    subscription = ActiveSupport::Notifications.subscribe("embargo_lifted.recording_studio_embargo") do |*args|
      notices << ActiveSupport::Notifications::Event.new(*args)
    end
    yield
    notices
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription) if subscription
  end
end
