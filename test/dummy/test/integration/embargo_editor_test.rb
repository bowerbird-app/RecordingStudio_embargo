# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class EmbargoEditorTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @owner = User.create!(
      email: "editor-owner-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
    @stranger = User.create!(
      email: "editor-stranger-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
    workspace = Workspace.create!(name: "Editor #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(workspace)
    @page = @root.record(Page, actor: @owner, parent_recording: @root) do |page|
      page.title = "Editor page #{SecureRandom.hex(4)}"
    end
    @folder = @root.record(Folder, actor: @owner, parent_recording: @root) do |folder|
      folder.name = "Editor folder #{SecureRandom.hex(4)}"
    end
    RecordingStudioAccessible.bootstrap_owner_access!(recording: @root, actor: @owner)
    @page.embargo_set!(
      {
        enabled: true,
        lifts_at: ActiveSupport::TimeZone["America/New_York"].parse("2026-11-02 09:00"),
        time_zone: "America/New_York",
        early_access: true
      },
      actor: @owner
    )
  end

  teardown do
    Current.actor = nil
  end

  test "editor renders the release fields and one early-access switch" do
    sign_in @owner

    get recording_studio_embargo.edit_recording_embargo_path(@page)

    assert_response :success
    assert_includes response.body, "data-recording-studio-default-layout"
    assert_select "turbo-frame", count: 0
    assert_select "#embargo-editor"
    assert_select "#embargo-status", count: 0
    assert_select "#embargo-form"
    assert_select "input[name='embargo[enabled]']"
    assert_select "input[name='embargo[early_access]']"
    assert_select "input[name='embargo[lifts_at]']"
    assert_includes response.body, 'name="embargo[time_zone]"'
    assert_includes response.body, 'value="Eastern Time (US &amp; Canada)" selected="selected"'
    refute_includes response.body, 'value="America/New_York"'
    refute_includes response.body, "Anyone"
    refute_includes response.body, "Restricted presentation"
    assert_select "input[name='embargo[fallback]']", count: 0
    assert_includes response.body, "2026-11-02T09:00"
    assert_includes response.body, "Embargoes give journalists advance notice of upcoming news, allowing them to plan and prepare their stories before the official release."
    assert_includes response.body, "Display your press kit as a preview marked for embargo"
    assert_includes response.body, "Only journalists you give access to will see it early. Embargoes work on an honour system. Journalists receive early access and agree not to publish until the release date. For example, sharing award winners in advance gives journalists time to prepare their stories before the announcement."
    refute_includes response.body, "listed actions"
    refute_includes response.body, "per action"
  end

  test "saving updates the embargo and an invalid release is rejected" do
    sign_in @owner
    release = 4.days.from_now.change(sec: 0)

    patch recording_studio_embargo.recording_embargo_path(@page), params: embargo_params(
      lifts_at: release.strftime("%Y-%m-%dT%H:%M"),
      time_zone: "America/Chicago",
      early_access: "0"
    )

    assert_redirected_to recording_studio_embargo.edit_recording_embargo_path(@page)
    follow_redirect!
    assert_includes response.body, "Embargo saved"
    embargo = @page.reload.current_embargo
    assert_equal "America/Chicago", embargo.time_zone
    refute embargo.early_access?
    assert embargo.active?

    patch recording_studio_embargo.recording_embargo_path(@page), params: embargo_params(
      lifts_at: 2.days.ago.strftime("%Y-%m-%dT%H:%M")
    )

    assert_response :unprocessable_entity
    assert_includes response.body, "data-recording-studio-default-layout"
    assert_includes response.body, "future"
  end

  test "a turbo frame edit renders the editor without the page layout" do
    sign_in @owner

    get recording_studio_embargo.edit_recording_embargo_path(@page), headers: frame_headers

    assert_response :success
    assert_equal "text/html", response.media_type
    assert_select "turbo-frame#presskit_embargo #embargo-editor"
    assert_select "#embargo-form"
    refute_includes response.body, "data-recording-studio-default-layout"
    refute_includes response.body, "<html"
    refute_includes response.body, "flat-pack--modal"
    refute_includes response.body, "data-modal-id"
  end

  test "saving inside a turbo frame stays there and refreshes the button" do
    sign_in @owner
    release = 4.days.from_now.change(sec: 0)

    patch recording_studio_embargo.recording_embargo_path(@page),
      params: embargo_params(enabled: "0", lifts_at: "", early_access: "0"),
      headers: frame_headers(stream: true)

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_includes response.body, "Embargo saved"
    assert_includes response.body, %(target="presskit_embargo")
    assert_includes button_stream, "+ Embargo"
    assert_includes button_stream, 'data-turbo-frame="presskit_embargo"'
    refute_includes button_stream, "Embargoed"
    refute @page.reload.current_embargo.active?

    patch recording_studio_embargo.recording_embargo_path(@page),
      params: embargo_params(lifts_at: release.strftime("%Y-%m-%dT%H:%M")),
      headers: frame_headers(stream: true)

    assert_response :success
    assert_includes response.body, "Embargo saved"
    assert_includes button_stream, "Embargoed"
    assert_includes button_stream, 'data-turbo-frame="presskit_embargo"'
    refute_includes button_stream, "+ Embargo"
    assert @page.reload.current_embargo.active?
  end

  test "a frame save without a stream response re-renders the editor in the frame" do
    sign_in @owner

    patch recording_studio_embargo.recording_embargo_path(@page),
      params: embargo_params(lifts_at: 5.days.from_now.strftime("%Y-%m-%dT%H:%M")),
      headers: frame_headers

    assert_response :success
    assert_equal "text/html", response.media_type
    assert_select "turbo-frame#presskit_embargo"
    assert_includes response.body, "Embargo saved"
    refute_includes response.body, "data-recording-studio-default-layout"
  end

  test "a turbo stream accept without a frame still redirects to the full editor" do
    sign_in @owner

    patch recording_studio_embargo.recording_embargo_path(@page),
      params: embargo_params(lifts_at: 5.days.from_now.strftime("%Y-%m-%dT%H:%M")),
      headers: { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }

    assert_redirected_to recording_studio_embargo.edit_recording_embargo_path(@page)
  end

  test "validation errors inside a turbo frame re-render in the frame" do
    sign_in @owner

    patch recording_studio_embargo.recording_embargo_path(@page),
      params: embargo_params(lifts_at: 2.days.ago.strftime("%Y-%m-%dT%H:%M")),
      headers: frame_headers(stream: true)

    assert_response :unprocessable_entity
    assert_equal "text/html", response.media_type
    assert_select "turbo-frame#presskit_embargo #embargo-form"
    assert_includes response.body, "future"
    refute_includes response.body, "data-recording-studio-default-layout"
    assert @page.reload.current_embargo.active?
  end

  test "editors without the manage role are forbidden and other recordables are missing" do
    sign_in @stranger
    get recording_studio_embargo.edit_recording_embargo_path(@page)
    assert_response :forbidden

    sign_in @owner
    get recording_studio_embargo.edit_recording_embargo_path(@folder)
    assert_response :not_found

    get recording_studio_embargo.edit_recording_embargo_path("missing")
    assert_response :not_found
  end

  test "sample responses follow embargo composition and drop the restriction after release" do
    get embargo_sample_path(@page)
    assert_response :not_found
    assert_equal "hidden", response.body
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert response.headers["X-Embargo-Expires-In"].to_i.positive?
    anonymous_key = response.headers["X-Embargo-Cache-Key"]

    get embargo_sample_download_path(@page)
    assert_response :forbidden
    assert_equal "DOWNLOAD_DENIED", response.body

    sign_in @owner
    get embargo_sample_path(@page)
    assert_equal "full", response.body
    refute_equal anonymous_key, response.headers["X-Embargo-Cache-Key"]

    get embargo_sample_download_path(@page)
    assert_response :success
    assert_equal "DOWNLOAD_OK", response.body

    sign_out @owner
    travel_to(@page.current_embargo.lifts_at) do
      get embargo_sample_path(@page)
      assert_equal "full", response.body
      assert_nil response.headers["X-Embargo-Cache-Key"]

      get embargo_sample_download_path(@page)
      assert_response :success
      assert_equal "DOWNLOAD_OK", response.body
    end
  end

  private

  def embargo_params(lifts_at:, time_zone: "America/New_York", early_access: "1", enabled: "1")
    {
      embargo: {
        enabled: enabled,
        lifts_at: lifts_at,
        time_zone: time_zone,
        early_access: early_access
      }
    }
  end

  def frame_headers(frame_id = "presskit_embargo", stream: false)
    headers = { "Turbo-Frame" => frame_id }
    if stream
      headers["Accept"] = "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"
    else
      headers["Accept"] = "text/html, application/xhtml+xml"
    end
    headers
  end

  def button_stream
    wrapper_id = RecordingStudioEmbargo::EmbargoButton::Component.wrapper_id(@page)
    Nokogiri::HTML(response.body).at_css("turbo-stream[target='#{wrapper_id}']")&.to_html.to_s
  end
end
