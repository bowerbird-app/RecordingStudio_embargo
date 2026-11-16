# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"
require "active_job/test_helper"

class EmbargoManageGateTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    RecordingStudio::Gates.reset!
    @previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    @owner = create_user("gate-owner")
    @stranger = create_user("gate-stranger")
    workspace = Workspace.create!(name: "Gate #{SecureRandom.hex(4)}")
    @root = RecordingStudio.create_root_recording!(workspace, actor: @owner)
    @page = @root.record(Page, actor: @owner, parent_recording: @root) do |page|
      page.title = "Gate page #{SecureRandom.hex(4)}"
    end
    RecordingStudioAccessible.bootstrap_owner_access!(recording: @root, actor: @owner)
    @lifts_at = 2.days.from_now.change(usec: 0)
    @page.embargo_set!(
      {
        enabled: true,
        lifts_at: @lifts_at,
        time_zone: "America/New_York",
        accepts_early_access_requests: true
      },
      actor: @owner
    )
  end

  teardown do
    RecordingStudio::Gates.reset!
    ActiveJob::Base.queue_adapter = @previous_adapter
    Current.actor = nil
  end

  test "a gate with no checks allows edit and update" do
    sign_in @owner

    get edit_path

    assert_response :success
    assert_select "#embargo-form"
    assert RecordingStudioEmbargo.manage_allowed?(recording: @page, actor: @owner)

    patch update_path, params: embargo_params(time_zone: "America/Chicago")

    assert_redirected_to edit_path
    assert_equal "America/Chicago", @page.reload.current_embargo.time_zone
  end

  test "a denying check blocks edit, update, upsert, and cancel" do
    register_check { false }
    sign_in @owner

    get edit_path
    assert_response :forbidden
    refute_includes response.body, "embargo-form"

    patch update_path, params: embargo_params(time_zone: "America/Chicago")
    assert_response :forbidden
    assert_equal "America/New_York", @page.reload.current_embargo.time_zone

    error = assert_raises(RecordingStudioEmbargo::Unauthorized) do
      @page.embargo_set!({ lifts_at: 5.days.from_now }, actor: @owner)
    end
    assert_includes error.message, "not allowed"
    assert_equal @lifts_at, @page.reload.current_embargo.lifts_at

    error = assert_raises(RecordingStudioEmbargo::Unauthorized) do
      @page.embargo_cancel!(actor: @owner)
    end
    assert_includes error.message, "not allowed"
    assert @page.reload.embargo_active?
    refute @page.embargo_child_recording.events.exists?(action: "embargo_cancelled")
  end

  test "a same-origin redirect is followed and an off-site redirect is refused" do
    register_check { RecordingStudio::GateDecision.deny(redirect_to: "/docs/install") }
    sign_in @owner

    get edit_path
    assert_redirected_to "/docs/install"

    patch update_path, params: embargo_params(time_zone: "America/Chicago")
    assert_redirected_to "/docs/install"
    assert_equal "America/New_York", @page.reload.current_embargo.time_zone

    RecordingStudio::Gates.reset!
    register_check { RecordingStudio::GateDecision.deny(redirect_to: "https://evil.test/plans") }

    get edit_path
    assert_response :forbidden
    assert_nil response.headers["Location"]

    patch update_path, params: embargo_params(time_zone: "America/Chicago")
    assert_response :forbidden
    assert_nil response.headers["Location"]
    assert_equal "America/New_York", @page.reload.current_embargo.time_zone
  end

  test "a check that raises denies the editor and the save" do
    register_check { raise "plan lookup failed" }
    sign_in @owner

    get edit_path
    assert_response :forbidden

    assert_raises(RecordingStudioEmbargo::Unauthorized) do
      @page.embargo_set!({ lifts_at: 5.days.from_now }, actor: @owner)
    end
    assert_equal @lifts_at, @page.reload.current_embargo.lifts_at
    assert @page.current_embargo.active?
  end

  test "accessible still forbids an editor when the gate allows" do
    register_check { true }
    sign_in @stranger

    assert RecordingStudioEmbargo.manage_allowed?(recording: @page, actor: @stranger)

    get edit_path
    assert_response :forbidden

    error = assert_raises(RecordingStudioEmbargo::Unauthorized) do
      @page.embargo_set!({ lifts_at: 5.days.from_now }, actor: @stranger)
    end
    assert_includes error.message, "not allowed"
    assert @page.reload.embargo_active?
  end

  test "a lapsed plan refuses clearing and the scheduled lift still runs with no actor" do
    RecordingStudio.register_gate(RecordingStudioEmbargo::MANAGE_GATE, "host.plan") do |actor:, **|
      actor.present? && actor != @owner
    end
    Current.actor = nil

    assert_raises(RecordingStudioEmbargo::Unauthorized) do
      @page.embargo_cancel!(actor: @owner)
    end
    assert_raises(RecordingStudioEmbargo::Unauthorized) do
      @page.embargo_cancel!(actor: nil)
    end
    assert @page.reload.current_embargo.enabled?
    assert @page.embargo_active?
    refute @page.embargo_child_recording.events.exists?(action: "embargo_cancelled")

    travel_to(@lifts_at) do
      RecordingStudioEmbargo::LiftTransitionJob.perform_now(@page.id.to_s, @lifts_at.iso8601(6))
      refute @page.reload.embargo_active?
    end

    child = @page.embargo_child_recording
    assert child.events.exists?(action: "embargo_lifted")
    refute child.events.exists?(action: "embargo_cancelled")
    assert @page.reload.current_embargo.enabled?
    refute RecordingStudioEmbargo.manage_allowed?(recording: @page, actor: nil)
    refute RecordingStudioEmbargo.manage_allowed?(recording: @page, actor: @owner)
  end

  test "cancel still clears the hold when the gate allows" do
    @page.embargo_cancel!(actor: @owner)

    refute @page.reload.embargo_active?
    assert @page.current_embargo.present?
    assert @page.embargo_child_recording.events.exists?(action: "embargo_cancelled")
  end

  test "the management path stays available while the gate denies" do
    register_check { false }
    sign_in @owner

    get root_path(recording_id: @page.id)

    expected = recording_studio_embargo.edit_recording_embargo_path(
      @page,
      return_to: root_path(recording_id: @page.id)
    )
    menu = Nokogiri::HTML(response.body).at_css("#embargo-menu-item")&.to_html.to_s

    assert_includes menu, %(href="#{expected}")
    assert_includes menu, "Embargoed"
    assert @controller.view_context.embargoed?(@page)
    assert_equal edit_path, @controller.view_context.recording_studio_embargo_management_path(@page)
  end

  private

  def edit_path
    recording_studio_embargo.edit_recording_embargo_path(@page)
  end

  def update_path
    recording_studio_embargo.recording_embargo_path(@page)
  end

  def embargo_params(time_zone:)
    {
      embargo: {
        enabled: "1",
        lifts_at: @lifts_at.strftime("%Y-%m-%dT%H:%M"),
        time_zone: time_zone,
        accepts_early_access_requests: "1"
      }
    }
  end

  def register_check(&block)
    RecordingStudio.register_gate("embargo.manage", "host.plan", &block)
  end

  def create_user(prefix)
    User.create!(
      email: "#{prefix}-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
  end
end
