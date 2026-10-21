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
    assert_select "input[name='return_to']", count: 0
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

  test "a full-page save redirects to a same-origin return path" do
    sign_in @owner
    destination = root_path(recording_id: @page.id)

    patch recording_studio_embargo.recording_embargo_path(@page), params: embargo_params(
      lifts_at: 4.days.from_now.strftime("%Y-%m-%dT%H:%M"),
      return_to: destination
    )

    assert_redirected_to destination
    follow_redirect!
    assert_includes response.body, "Embargo saved"
    assert @page.reload.current_embargo.active?
  end

  test "an unsafe return path falls back to the editor" do
    sign_in @owner

    patch recording_studio_embargo.recording_embargo_path(@page), params: embargo_params(
      lifts_at: 4.days.from_now.strftime("%Y-%m-%dT%H:%M"),
      return_to: "https://evil.test/phish"
    )

    assert_redirected_to recording_studio_embargo.edit_recording_embargo_path(@page)

    get recording_studio_embargo.edit_recording_embargo_path(@page), params: { return_to: "//evil.test/phish" }

    assert_response :success
    assert_select "input[name='return_to']", count: 0
  end

  test "the editor keeps a safe return path for the next save" do
    sign_in @owner

    get recording_studio_embargo.edit_recording_embargo_path(@page), params: { return_to: "/docs/install" }

    assert_response :success
    assert_select "input[name='return_to'][value='/docs/install']"
    assert_select "button[aria-label='Back']"
  end

  test "saving inside a turbo frame refreshes the page and does not replace host markup" do
    sign_in @owner
    before = @page.reload.updated_at

    travel 2.seconds do
      patch recording_studio_embargo.recording_embargo_path(@page),
        params: embargo_params(enabled: "0", lifts_at: "", early_access: "0"),
        headers: frame_headers(stream: true)
    end

    assert_refresh_stream
    refute @page.reload.current_embargo.active?
    assert_operator @page.updated_at, :>, before

    patch recording_studio_embargo.recording_embargo_path(@page),
      params: embargo_params(lifts_at: 4.days.from_now.strftime("%Y-%m-%dT%H:%M")),
      headers: frame_headers

    assert_refresh_stream
    assert @page.reload.current_embargo.active?
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

  def frame_headers(frame_id = "presskit_embargo", stream: false)
    headers = { "Turbo-Frame" => frame_id }
    if stream
      headers["Accept"] = "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"
    else
      headers["Accept"] = "text/html, application/xhtml+xml"
    end
    headers
  end

  def embargo_params(lifts_at:, time_zone: "America/New_York", early_access: "1", enabled: "1", return_to: nil)
    params = {
      embargo: {
        enabled: enabled,
        lifts_at: lifts_at,
        time_zone: time_zone,
        early_access: early_access
      }
    }
    params[:return_to] = return_to if return_to
    params
  end

  def assert_refresh_stream
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    stream = Nokogiri::HTML(response.body).at_css("turbo-stream")
    assert_equal "refresh", stream["action"]
    assert_equal "morph", stream["method"]
    assert_equal "preserve", stream["scroll"]
    assert_nil stream["request-id"]
    assert_nil stream["target"]
    assert_select "turbo-stream", count: 1
    refute_includes response.body, "embargo_button"
    refute_includes response.body, "embargo-editor-modal"
    refute_includes response.body, "Embargo saved"
    refute_includes response.body, "action=\"replace\""
    refute_includes response.body, "action=\"update\""
  end
end
