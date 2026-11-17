# frozen_string_literal: true

require "test_helper"
require "active_job/test_helper"

class EmbargoPolicyTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    @owner = create_user("owner")
    @viewer = create_user("viewer")
    @editor = create_user("editor")
    @workspace = Workspace.create!(name: "Embargo #{SecureRandom.hex(4)}")
    @root = RecordingStudio.create_root_recording!(@workspace, actor: @owner)
    @page = @root.record(Page, actor: @owner, parent_recording: @root) do |page|
      page.title = "Held page #{SecureRandom.hex(4)}"
    end
    RecordingStudioAccessible.bootstrap_owner_access!(recording: @root, actor: @owner)
    grant(@viewer, :view)
    grant(@editor, :edit)
  end

  teardown do
    ActiveJob::Base.queue_adapter = @previous_adapter
    Current.actor = nil
  end

  test "history keeps the actor and a cancel does not erase it" do
    activate!
    created = history_actions
    assert_includes created, "embargo_created"
    created_event = @page.embargo_history.find_by!(action: "embargo_created")
    assert_equal @owner, created_event.actor

    @page.embargo_set!({ lifts_at: 4.days.from_now }, actor: @editor)
    @page.embargo_cancel!(actor: @owner)

    assert_equal %w[embargo_created embargo_updated embargo_cancelled], history_actions
    assert_equal 1, @page.child_recordings.of_type(RecordingStudioEmbargo::Embargo).kept.count
    refute @page.reload.embargo_active?
    assert @page.current_embargo.present?
  end

  test "embargo child lookup follows Recording.kept" do
    activate!
    child = @page.embargo_child_recording
    child.update_columns(trashed_at: Time.current)

    RecordingStudio.unregister_recording_filter(:trashable)
    assert_equal child, @page.embargo_child_recording

    RecordingStudio.register_recording_filter(
      :embargo_test_kept,
      sql: ->(table) { "#{table}.trashed_at IS NULL" }
    ) { |recordings| recordings.where(trashed_at: nil) }

    assert_nil @page.embargo_child_recording
  ensure
    RecordingStudio.unregister_recording_filter(:embargo_test_kept)
    if defined?(RecordingStudioTrashable::RecordingFilter)
      RecordingStudioTrashable::RecordingFilter.register!
    end
  end

  test "a trashed embargo does not block a new kept embargo" do
    RecordingStudio.register_recording_filter(
      :embargo_replacement_kept,
      sql: ->(table) { "#{table}.trashed_at IS NULL" }
    ) { |recordings| recordings.where(trashed_at: nil) }

    activate!
    trashed = @page.embargo_child_recording
    trashed.update_columns(trashed_at: Time.current)

    @page.embargo_set!(enabled_attributes, actor: @owner)

    replacement = @page.embargo_child_recording
    children = @page.child_recordings.of_type(RecordingStudioEmbargo::Embargo)
    refute_equal trashed.id, replacement.id
    assert_equal 1, children.kept.count
    assert_equal 2, children.count
    refute ActiveRecord::Base.connection.index_exists?(
      :recording_studio_recordings,
      :parent_recording_id,
      name: "index_rs_embargo_child_per_parent"
    )
  ensure
    RecordingStudio.unregister_recording_filter(:embargo_replacement_kept)
  end

  test "lift notification is idempotent and ignores a rescheduled instant" do
    first_lift = 2.days.from_now.change(usec: 0)
    second_lift = 5.days.from_now.change(usec: 0)
    activate!(lifts_at: first_lift)
    assert_enqueued_with(job: RecordingStudioEmbargo::LiftTransitionJob)

    @page.embargo_set!({ lifts_at: second_lift }, actor: @owner)
    travel_to(first_lift + 1.minute) do
      RecordingStudioEmbargo::LiftTransitionJob.perform_now(@page.id.to_s, first_lift.iso8601(6))
      assert_empty lift_events
    end

    travel_to(second_lift) do
      RecordingStudioEmbargo.observe_lift!(@page.reload)
      RecordingStudioEmbargo.observe_lift!(@page.reload)
    end

    assert_equal 1, lift_events.count
    assert_equal @owner, lift_events.sole.actor
  end

  test "an editor who fails the manage gate keeps the embargo on the copy" do
    checked = []
    allow_manage_only(@owner) { |recording| checked << recording }
    lifts_at = 3.days.from_now.change(usec: 0)
    activate!(lifts_at: lifts_at)
    copy = record_page("Kept copy")
    checked.clear

    assert_enqueued_jobs 1, only: RecordingStudioEmbargo::LiftTransitionJob do
      RecordingStudioEmbargo.copy_onto!(source_recording: @page, copy_recording: copy, actor: @editor)
    end

    copied = copy.reload.current_embargo
    source = @page.reload.current_embargo
    assert_equal [@page], checked
    assert copy.embargo_active?
    assert @page.embargo_active?
    assert_equal source.lifts_at, copied.lifts_at
    assert_equal "America/New_York", copied.time_zone
    assert copied.enabled?
    assert copied.accepts_early_access_requests?
    refute_equal source.id, copied.id
    assert_equal [copy.id.to_s, copied.lifts_at.iso8601(6)], lift_job_args(copy)
  ensure
    RecordingStudio::Gates.reset!
  end

  test "an actor without the manage role keeps the embargo on the copy" do
    RecordingStudio::Gates.reset!
    activate!
    copy = record_page("Viewer copy")

    assert_enqueued_jobs 1, only: RecordingStudioEmbargo::LiftTransitionJob do
      RecordingStudioEmbargo.copy_onto!(source_recording: @page, copy_recording: copy, actor: @viewer)
    end

    assert copy.reload.embargo_active?
    assert_equal @page.reload.current_embargo.lifts_at, copy.current_embargo.lifts_at
  ensure
    RecordingStudio::Gates.reset!
  end

  test "copying with a missing actor keeps the embargo and stores no actor" do
    RecordingStudio::Gates.reset!
    lifts_at = 4.days.from_now.change(usec: 0)
    activate!(lifts_at: lifts_at, accepts_early_access_requests: false)
    copy = record_page("Anonymous copy")

    assert_enqueued_jobs 1, only: RecordingStudioEmbargo::LiftTransitionJob do
      RecordingStudioEmbargo.copy_onto!(source_recording: @page, copy_recording: copy, actor: nil)
    end

    copied = copy.reload.current_embargo
    assert copy.embargo_active?
    assert_equal @page.reload.current_embargo.lifts_at.to_i, copied.lifts_at.to_i
    assert_equal "America/New_York", copied.time_zone
    refute copied.accepts_early_access_requests?
    assert_nil copy.embargo_child_recording.events.order(:occurred_at, :created_at).first.actor
    assert_equal copy.id.to_s, lift_job_args(copy).first
    refute RecordingStudio.configuration.allow_unauthorized_writes
    refute RecordingStudio.configuration.authorize_write.call(actor: nil)
  ensure
    RecordingStudio::Gates.reset!
  end

  test "a manager who passes the role and the gate clears the embargo on the copy" do
    allow_manage_only(@owner)
    activate!
    copy = record_page("Cleared copy")

    assert_no_enqueued_jobs only: RecordingStudioEmbargo::LiftTransitionJob do
      RecordingStudioEmbargo.copy_onto!(source_recording: @page, copy_recording: copy, actor: @owner)
    end

    assert @page.reload.embargo_active?
    refute copy.reload.embargo_active?
    assert_nil copy.current_embargo
  ensure
    RecordingStudio::Gates.reset!
  end

  test "copying a lifted embargo does not raise for an editor or a missing actor" do
    allow_manage_only(@owner)
    lifts_at = 1.hour.from_now.change(usec: 0)
    activate!(lifts_at: lifts_at)
    editor_copy = record_page("Lifted editor")
    anonymous_copy = record_page("Lifted anonymous")

    travel_to(lifts_at + 1.minute) do
      assert_no_enqueued_jobs only: RecordingStudioEmbargo::LiftTransitionJob do
        RecordingStudioEmbargo.copy_onto!(source_recording: @page, copy_recording: editor_copy, actor: @editor)
        RecordingStudioEmbargo.copy_onto!(source_recording: @page, copy_recording: anonymous_copy, actor: nil)
      end
    end

    refute editor_copy.reload.embargo_active?
    refute anonymous_copy.reload.embargo_active?
    assert_nil editor_copy.current_embargo
    assert_nil anonymous_copy.current_embargo
  ensure
    RecordingStudio::Gates.reset!
  end

  test "enabling requires a future release and the manage role" do
    error = assert_raises(RecordingStudioEmbargo::Invalid) do
      activate!(lifts_at: 1.hour.ago)
    end
    assert_includes error.message, "future"

    error = assert_raises(RecordingStudioEmbargo::Unauthorized) do
      @page.embargo_set!(enabled_attributes, actor: @viewer)
    end
    assert_includes error.message, "not allowed"
  end

  test "cache key ignores who is asking and expires at the release" do
    lifts_at = 3.hours.from_now.change(usec: 0)
    activate!(lifts_at: lifts_at)
    embargo = @page.current_embargo
    owner_key = RecordingStudioEmbargo.cache_key(@page, at: Time.current)
    viewer_key = RecordingStudioEmbargo::Cache.key(@page, at: Time.current)

    assert_equal owner_key, viewer_key
    assert_equal [embargo.id, true, embargo.lifts_at.utc.iso8601], owner_key
    refute_includes owner_key, @owner.id
    refute_includes owner_key, @viewer.id
    refute_includes owner_key, nil
    assert_in_delta 3.hours, RecordingStudioEmbargo.cache_expires_in(@page), 5

    travel_to(lifts_at) do
      assert_nil RecordingStudioEmbargo.cache_expires_in(@page.reload)
      assert_equal owner_key, RecordingStudioEmbargo.cache_key(@page, at: Time.current)
    end
  end

  private

  def create_user(prefix, email: nil)
    User.create!(
      email: email || "#{prefix}-#{SecureRandom.hex(4)}@example.com",
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

  def activate!(lifts_at: 3.days.from_now, accepts_early_access_requests: true)
    @page.embargo_set!(
      {
        enabled: true,
        lifts_at: lifts_at,
        time_zone: "America/New_York",
        accepts_early_access_requests: accepts_early_access_requests
      },
      actor: @owner
    )
  end

  def enabled_attributes
    {
      enabled: true,
      lifts_at: 2.days.from_now,
      time_zone: "UTC",
      accepts_early_access_requests: true
    }
  end

  def history_actions
    names = %w[embargo_created embargo_updated embargo_cancelled embargo_lifted]
    @page.embargo_child_recording.events.unscope(:order).where(action: names).order(:occurred_at, :created_at).map(&:action)
  end

  def lift_events
    @page.embargo_child_recording.events.where(action: "embargo_lifted")
  end

  def record_page(title)
    @root.record(Page, actor: @owner, parent_recording: @root) do |page|
      page.title = "#{title} #{SecureRandom.hex(4)}"
    end
  end

  def allow_manage_only(allowed)
    RecordingStudio::Gates.reset!
    RecordingStudio.register_gate("embargo.manage", "embargo_policy.copy") do |actor:, recording:, **|
      yield recording if block_given?
      actor == allowed
    end
  end

  def lift_job_args(recording)
    job = ActiveJob::Base.queue_adapter.enqueued_jobs.reverse.find do |entry|
      entry[:job] == RecordingStudioEmbargo::LiftTransitionJob && entry[:args]&.first == recording.id.to_s
    end
    assert job, "expected a lift job for the copy"
    job[:args]
  end
end
