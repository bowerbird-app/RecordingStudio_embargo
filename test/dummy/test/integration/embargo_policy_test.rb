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

  test "can_manage is the manage role and the embargo.manage gate" do
    assert RecordingStudioEmbargo.manage_allowed?(recording: @page, actor: @viewer)
    refute RecordingStudioEmbargo.can_manage?(recording: @page, actor: @viewer)
    assert RecordingStudioEmbargo.can_manage?(recording: @page, actor: @editor)
    refute RecordingStudioEmbargo.can_manage?(recording: @page, actor: nil)

    allow_manage_only(@owner)
    refute RecordingStudioEmbargo.can_manage?(recording: @page, actor: @editor)
    assert RecordingStudioEmbargo.can_manage?(recording: @page, actor: @owner)
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

  def enabled_attributes(lifts_at: 2.days.from_now)
    {
      enabled: true,
      lifts_at: lifts_at,
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

  def allow_manage_only(allowed)
    RecordingStudio::Gates.reset!
    RecordingStudio.register_gate("embargo.manage", "embargo_policy.manage") do |actor:, recording:, **|
      yield recording if block_given?
      actor == allowed
    end
  end

end
