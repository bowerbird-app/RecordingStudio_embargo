# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class EmbargoButtonTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @owner = create_user("button-owner")
    @viewer = create_user("button-viewer")
    @stranger = create_user("button-stranger")
    workspace = Workspace.create!(name: "Button #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(workspace)
    @page = @root.record(Page, actor: @owner, parent_recording: @root) do |page|
      page.title = "Button page #{SecureRandom.hex(4)}"
    end
    @folder = @root.record(Folder, actor: @owner, parent_recording: @root) do |folder|
      folder.name = "Button folder #{SecureRandom.hex(4)}"
    end
    RecordingStudioAccessible.bootstrap_owner_access!(recording: @root, actor: @owner)
    grant(@viewer, :view)
  end

  teardown do
    Current.actor = nil
  end

  test "an active embargo renders a warning Embargoed button for an editor" do
    activate!
    sign_in @owner

    get root_path(recording_id: @page.id)

    section = button_html(@page)
    assert_includes section, "Embargoed"
    assert_includes section, 'data-fp-style="warning"'
    assert_includes section, 'data-flat-pack--icon-name-value="lock-closed"'
    assert_includes section, edit_path(@page)
    refute_includes section, "+ Embargo"
  end

  test "no embargo renders a secondary add button" do
    sign_in @owner

    get root_path(recording_id: @page.id)

    assert_add_button
  end

  test "a disabled embargo renders the add button" do
    @page.embargo_set!(
      { enabled: false, lifts_at: nil, time_zone: "UTC", early_access: false },
      actor: @owner
    )
    sign_in @owner

    get root_path(recording_id: @page.id)

    assert_add_button
  end

  test "an expired embargo renders the add button" do
    activate!(lifts_at: 1.hour.from_now)
    sign_in @owner

    travel_to(2.hours.from_now) do
      get root_path(recording_id: @page.id)
    end

    assert_add_button
  end

  test "people who cannot edit the embargo see no button" do
    activate!

    sign_in @viewer
    get root_path(recording_id: @page.id)
    assert_empty button_html(@page)

    sign_in @stranger
    get root_path(recording_id: @page.id)
    assert_empty button_html(@page)

    sign_in @owner
    get root_path(recording_id: @folder.id)
    assert_empty button_html(@folder)
  end

  test "the host helper renders the component" do
    source = Rails.root.join("app/views/home/index.html.erb").read
    assert_includes source, "render_embargo_button(@page_recording)"
    assert_includes ApplicationHelper.ancestors, RecordingStudioEmbargo::ApplicationHelper
    assert_equal "embargo_button_#{@page.id}", RecordingStudioEmbargo::EmbargoButton::Component.wrapper_id(@page)

    activate!
    sign_in @owner
    get root_path(recording_id: @page.id)

    assert_select "##{RecordingStudioEmbargo::EmbargoButton::Component.wrapper_id(@page)}"
  end

  private

  def assert_add_button
    section = button_html(@page)
    assert_includes section, "+ Embargo"
    assert_includes section, 'data-fp-style="secondary"'
    assert_includes section, edit_path(@page)
    refute_includes section, "Embargoed"
    refute_includes section, "lock-closed"
  end

  def button_html(recording)
    wrapper = RecordingStudioEmbargo::EmbargoButton::Component.wrapper_id(recording)
    Nokogiri::HTML(response.body).at_css("##{wrapper}")&.to_html.to_s
  end

  def edit_path(recording)
    recording_studio_embargo.edit_recording_embargo_path(recording)
  end

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

  def activate!(lifts_at: 3.days.from_now)
    @page.embargo_set!(
      { enabled: true, lifts_at: lifts_at, time_zone: "UTC", early_access: false },
      actor: @owner
    )
  end
end
