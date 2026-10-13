# frozen_string_literal: true

require "test_helper"
require "active_job/test_helper"

class EmbargoPolicyTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  SHOW = :"pages.show"
  DOWNLOAD = :"pages.download"

  setup do
    @previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    @owner = create_user("owner")
    @viewer = create_user("viewer")
    @editor = create_user("editor")
    @workspace = Workspace.create!(name: "Embargo #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
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

  test "an active embargo denies a public baseline and admits a granted actor" do
    activate!
    set_baseline(SHOW, :public)

    assert_equal :public, RecordingStudioAccessible.effective_audience(recording: @page, action: SHOW)
    assert_equal :deny, restriction(actor: nil, action: SHOW)
    assert_equal :allow, restriction(actor: @viewer, action: SHOW)
    refute permitted?(actor: nil, action: SHOW)
    assert permitted?(actor: @viewer, action: SHOW)
  end

  test "early access off denies a granted actor until the release" do
    activate!(early_access: false)
    set_baseline(SHOW, :public)

    assert_equal :deny, restriction(actor: nil, action: SHOW)
    assert_equal :deny, restriction(actor: @viewer, action: SHOW)
    refute permitted?(actor: @viewer, action: SHOW)
  end

  test "a view grant does not satisfy download" do
    activate!

    assert_equal :allow, restriction(actor: @viewer, action: SHOW)
    assert_equal :deny, restriction(actor: @viewer, action: DOWNLOAD)
    assert_equal :allow, restriction(actor: @editor, action: DOWNLOAD)
  end

  test "an action the capability does not list stays on the baseline" do
    activate!
    set_baseline(DOWNLOAD, :public)

    assert_equal :not_applicable, restriction(actor: nil, action: :"pages.other")
    assert_equal :deny, restriction(actor: nil, action: DOWNLOAD)
    refute permitted?(actor: nil, action: DOWNLOAD)
  end

  test "publishable withholding beats early access and expiry is a time read" do
    lifts_at = Time.zone.parse("2026-12-01 12:00:00")
    activate!(lifts_at: lifts_at)
    @page.define_singleton_method(:currently_published?) { |*| false }

    assert_equal :allow, restriction(actor: @viewer, action: SHOW)
    refute permitted?(actor: @viewer, action: SHOW)
    assert_equal :unavailable, presentation(actor: @viewer)
    assert_equal :full, presentation(actor: @viewer, purpose: :editor)

    @page.define_singleton_method(:currently_published?) { |*| true }
    travel_to(lifts_at) do
      assert_equal :not_applicable, restriction(actor: nil, action: SHOW)
      assert permitted?(actor: nil, action: SHOW)
      assert_equal :full, presentation(actor: nil)
    end
  end

  test "press kit presentation uses the host fallback while access is denied" do
    activate!
    @page.define_singleton_method(:currently_published?) { |*| true }

    assert_equal :hidden, presentation(actor: nil, normal_fallback: :hidden)
    assert_equal :preview, presentation(actor: nil, normal_fallback: :preview)
    assert_equal :full, presentation(actor: @viewer, normal_fallback: :hidden)
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
    assert_equal 1, @page.child_recordings.of_type(RecordingStudioEmbargo::Embargo).where(trashed_at: nil).count
    refute @page.reload.embargo_active?
    assert @page.current_embargo.present?
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
  end

  test "duplicating attributes does not carry early access or an active window" do
    activate!
    copy = RecordingStudioEmbargo.attributes_for_duplicate(@page.current_embargo)
    @page.embargo_set!(copy, actor: @owner)

    embargo = @page.reload.current_embargo
    refute embargo.enabled?
    assert_nil embargo.lifts_at
    refute embargo.early_access?
    assert_equal :not_applicable, restriction(actor: nil, action: SHOW)
  end

  test "enabling requires a future release and a known audience" do
    error = assert_raises(RecordingStudioEmbargo::Invalid) do
      activate!(lifts_at: 1.hour.ago)
    end
    assert_includes error.message, "future"

    error = assert_raises(RecordingStudioEmbargo::Unauthorized) do
      @page.embargo_set!(enabled_attributes, actor: @viewer)
    end
    assert_includes error.message, "not allowed"
  end

  test "cache identity includes the actor and stops at the release" do
    lifts_at = 3.hours.from_now.change(usec: 0)
    activate!(lifts_at: lifts_at)
    anonymous = RecordingStudioEmbargo.cache_key(@page, nil, SHOW)
    viewer = RecordingStudioEmbargo.cache_key(@page, @viewer, SHOW)

    refute_equal anonymous, viewer
    assert_includes anonymous, :deny
    assert_includes viewer, :allow
    assert_in_delta 3.hours, RecordingStudioEmbargo.cache_expires_in(@page), 5

    travel_to(lifts_at) do
      assert_nil RecordingStudioEmbargo.cache_expires_in(@page.reload)
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

  def activate!(lifts_at: 3.days.from_now, early_access: true)
    @page.embargo_set!(
      {
        enabled: true,
        lifts_at: lifts_at,
        time_zone: "America/New_York",
        early_access: early_access
      },
      actor: @owner
    )
  end

  def enabled_attributes
    {
      enabled: true,
      lifts_at: 2.days.from_now,
      time_zone: "UTC",
      early_access: true
    }
  end

  def set_baseline(action, audience)
    RecordingStudioAccessible.set_audience!(
      recording: @page,
      action: action,
      audience: audience,
      actor: @owner
    )
  end

  def restriction(actor:, action:)
    RecordingStudioEmbargo.restriction_for(recording: @page, action: action, actor: actor)
  end

  def permitted?(actor:, action:)
    RecordingStudioEmbargo.action_permitted?(recording: @page, action: action, actor: actor)
  end

  def presentation(actor:, purpose: :public, normal_fallback: :hidden)
    RecordingStudioEmbargo.presskit_presentation(
      recording: @page,
      actor: actor,
      view_action: SHOW,
      purpose: purpose,
      normal_fallback: normal_fallback
    )
  end

  def history_actions
    names = %w[embargo_created embargo_updated embargo_cancelled embargo_lifted]
    @page.embargo_child_recording.events.unscope(:order).where(action: names).order(:occurred_at, :created_at).map(&:action)
  end

  def lift_events
    @page.embargo_child_recording.events.where(action: "embargo_lifted")
  end

end
