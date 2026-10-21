# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class EmbargoHostLinkTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @owner = create_user("link-owner")
    @viewer = create_user("link-viewer")
    workspace = Workspace.create!(name: "Link #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(workspace)
    @page = @root.record(Page, actor: @owner, parent_recording: @root) do |page|
      page.title = "Link page #{SecureRandom.hex(4)}"
    end
    RecordingStudioAccessible.bootstrap_owner_access!(recording: @root, actor: @owner)
    grant(@viewer, :view)
  end

  teardown do
    Current.actor = nil
  end

  test "the host menu item and full-page link use the management path" do
    sign_in @owner

    get root_path(recording_id: @page.id)

    expected = recording_studio_embargo.edit_recording_embargo_path(
      @page,
      return_to: root_path(recording_id: @page.id)
    )
    menu = css("#embargo-menu-item")
    full_page = css("#embargo-full-page-link")

    assert_includes menu, "Embargo"
    assert_includes menu, %(href="#{expected}")
    assert_includes menu, 'data-modal-id="embargo-editor-modal"'
    assert_includes menu, 'data-turbo-frame="embargo_editor"'
    refute_includes menu, "lock-closed"
    refute_includes menu, "Embargoed"

    assert_includes full_page, "Open embargo page"
    assert_includes full_page, %(href="#{expected}")
    refute_includes full_page, "data-turbo-frame"
    refute_includes full_page, "data-modal-id"

    assert_select "#embargo-editor-modal turbo-frame#embargo_editor"
    assert_select "turbo-cable-stream-source", count: 1
    refute_includes response.body, "embargo_button_"
    refute_includes response.body, "render_embargo_button"
  end

  test "an active hold labels the menu item and embargoed? is true" do
    activate!
    sign_in @owner

    get root_path(recording_id: @page.id)

    menu = css("#embargo-menu-item")
    assert_includes menu, "Embargoed"
    assert_includes menu, 'data-flat-pack--icon-name-value="lock-closed"'
    assert @controller.view_context.embargoed?(@page)
  end

  test "a disabled or lifted hold is not embargoed" do
    sign_in @owner
    get root_path(recording_id: @page.id)
    refute @controller.view_context.embargoed?(@page)

    @page.embargo_set!(
      { enabled: false, lifts_at: nil, time_zone: "UTC", early_access: false },
      actor: @owner
    )
    refute @controller.view_context.embargoed?(@page.reload)

    activate!(lifts_at: 1.hour.from_now)
    travel_to(2.hours.from_now) do
      refute @controller.view_context.embargoed?(@page.reload)
    end
  end

  test "the management helper drops an unsafe return path" do
    sign_in @owner
    get root_path(recording_id: @page.id)
    view = @controller.view_context

    safe = view.recording_studio_embargo_management_path(@page, return_to: "/docs/install")
    unsafe = view.recording_studio_embargo_management_path(@page, return_to: "https://evil.test/phish")

    assert_equal recording_studio_embargo.edit_recording_embargo_path(@page, return_to: "/docs/install"), safe
    assert_equal recording_studio_embargo.edit_recording_embargo_path(@page), unsafe
    refute view.embargoed?(nil)
  end

  test "someone who cannot edit is still forbidden at the editor" do
    sign_in @viewer

    get recording_studio_embargo.edit_recording_embargo_path(@page)

    assert_response :forbidden
  end

  private

  def css(selector)
    Nokogiri::HTML(response.body).at_css(selector)&.to_html.to_s
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
