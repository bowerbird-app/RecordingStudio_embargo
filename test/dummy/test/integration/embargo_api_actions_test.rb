# frozen_string_literal: true

require "test_helper"

class EmbargoApiActionsTest < ActiveSupport::TestCase
  setup do
    @owner = create_user("owner")
    @viewer = create_user("viewer")
    @workspace = Workspace.create!(name: "API #{SecureRandom.hex(4)}")
    @other_workspace = Workspace.create!(name: "Other #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    @other_root = RecordingStudio.root_recording_for(@other_workspace)
    @page = record_page(@root, "Held page")
    @foreign_page = record_page(@other_root, "Foreign page")
    RecordingStudioAccessible.bootstrap_owner_access!(recording: @root, actor: @owner)
    grant(@viewer, :view)
    @lifts_at = 3.days.from_now.utc.change(sec: 0)
    RecordingStudioAccessible.bootstrap_owner_access!(recording: @other_root, actor: @owner)
  end

  test "HTML management and API required_role are both edit" do
    assert_equal :edit, RecordingStudioEmbargo.configuration.manage_role
    assert_equal :edit, RecordingStudioEmbargo.configuration.manage_role_for(@page)
    %i[set_embargo cancel_embargo show_embargo].each do |name|
      action = RecordingStudioApi.capability_action(name)

      assert_equal :edit, action.required_role
      assert_equal :embargo, action.capability
    end
  end

  test "set_embargo writes when the grant can edit" do
    result = RecordingStudioEmbargo::Api::SetEmbargo.call(
      action_context(actor: @owner, recording: @page, params: enabled_params)
    )

    assert_equal @page, result
    assert @page.reload.embargo_active?
    assert_equal true, @page.current_embargo.enabled
  end

  test "set_embargo is forbidden when the grant is only view" do
    error = assert_raises(RecordingStudioApi::AuthorizationError) do
      RecordingStudioEmbargo::Api::SetEmbargo.call(
        action_context(actor: @viewer, recording: @page, params: enabled_params)
      )
    end

    assert_equal "API access grant is not authorized for this capability", error.message
    assert_nil @page.reload.current_embargo
  end

  test "set_embargo hides a recording from another workspace" do
    error = assert_raises(RecordingStudioApi::NotFoundError) do
      RecordingStudioEmbargo::Api::SetEmbargo.call(
        action_context(actor: @owner, recording: @foreign_page, params: enabled_params)
      )
    end

    assert_equal "Recording was not found in this API scope", error.message
    assert_nil @foreign_page.reload.current_embargo
  end

  test "cancel_embargo clears the hold when the grant can edit" do
    @page.embargo_set!(enabled_params, actor: @owner)

    RecordingStudioEmbargo::Api::CancelEmbargo.call(
      action_context(actor: @owner, recording: @page, params: {})
    )

    refute @page.reload.embargo_active?
    assert_equal false, @page.current_embargo.enabled
  end

  test "cancel_embargo is forbidden when the grant is only view" do
    @page.embargo_set!(enabled_params, actor: @owner)

    assert_raises(RecordingStudioApi::AuthorizationError) do
      RecordingStudioEmbargo::Api::CancelEmbargo.call(
        action_context(actor: @viewer, recording: @page, params: {})
      )
    end

    assert @page.reload.embargo_active?
  end

  test "cancel_embargo hides a recording from another workspace" do
    @foreign_page.embargo_set!(enabled_params, actor: @owner)

    assert_raises(RecordingStudioApi::NotFoundError) do
      RecordingStudioEmbargo::Api::CancelEmbargo.call(
        action_context(actor: @owner, recording: @foreign_page, params: {})
      )
    end

    assert @foreign_page.reload.embargo_active?
  end

  test "show_embargo returns current_embargo and embargo_active?" do
    @page.embargo_set!(enabled_params, actor: @owner)

    recording = RecordingStudioEmbargo::Api::ShowEmbargo.call(
      action_context(actor: @owner, recording: @page, params: {})
    )
    payload = RecordingStudioEmbargo::Api::MemberAction.serialize(recording)

    assert_equal true, payload[:enabled]
    assert_equal true, payload[:active]
    assert_equal "UTC", payload[:time_zone]
    assert_equal true, payload[:early_access]
  end

  test "show_embargo is forbidden when the grant is only view" do
    assert_raises(RecordingStudioApi::AuthorizationError) do
      RecordingStudioEmbargo::Api::ShowEmbargo.call(
        action_context(actor: @viewer, recording: @page, params: {})
      )
    end
  end

  test "show_embargo hides a recording from another workspace" do
    assert_raises(RecordingStudioApi::NotFoundError) do
      RecordingStudioEmbargo::Api::ShowEmbargo.call(
        action_context(actor: @owner, recording: @foreign_page, params: {})
      )
    end
  end

  private

  def create_user(prefix)
    User.create!(
      email: "#{prefix}-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
  end

  def record_page(root, title)
    root.record(Page, actor: @owner, parent_recording: root) do |page|
      page.title = "#{title} #{SecureRandom.hex(4)}"
    end
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

  def enabled_params
    {
      enabled: true,
      lifts_at: @lifts_at,
      time_zone: "UTC",
      early_access: true
    }
  end

  def access_recording_for(actor, root)
    RecordingStudio::Recording
      .where(root_recording_id: root.id, recordable_type: "RecordingStudio::Access")
      .detect { |recording| recording.recordable.actor == actor }
  end

  def action_context(actor:, recording:, params:)
    root = recording.root_recording
    access_recording = access_recording_for(actor, @root)
    grant = RecordingStudioApi::AccessGrant.new(
      api_client: nil,
      credential: nil,
      access_recording: access_recording,
      root_recording: @root
    )

    RecordingStudioApi::ActionContext.new(
      recording: recording,
      api_client: nil,
      credential: nil,
      access_recording: access_recording,
      access_grant: grant,
      root_recording: root,
      params: params
    )
  end
end
