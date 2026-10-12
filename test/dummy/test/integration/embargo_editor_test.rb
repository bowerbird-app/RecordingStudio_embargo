# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class EmbargoEditorTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  SHOW = :"pages.show"
  DOWNLOAD = :"pages.download"

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
        early_access: { SHOW => "granted", DOWNLOAD => "granted" },
        fallback: "preview"
      },
      actor: @owner
    )
  end

  teardown do
    Current.actor = nil
  end

  test "editor renders host actions, release time, and status" do
    sign_in @owner

    get recording_studio_embargo.edit_recording_embargo_path(@page)

    assert_response :success
    assert_select "#embargo-editor"
    assert_select "#embargo-status", text: /Active/
    assert_select "#embargo-form"
    assert_select "input[name='embargo[enabled]']"
    assert_select "input[name='embargo[lifts_at]']"
    assert_includes response.body, 'name="embargo[time_zone]"'
    assert_includes response.body, 'value="Eastern Time (US &amp; Canada)" selected="selected"'
    refute_includes response.body, 'value="America/New_York"'
    assert_select "#embargo-action-pages-show legend", text: "View the page"
    assert_select "#embargo-action-pages-download legend", text: "Download the page"
    assert_includes response.body, "Who can open this page before the release time."
    assert_includes response.body, "Who can download before the release time."
    assert_select "#embargo-action-pages-show legend", text: "pages.show", count: 0
    assert_select "#embargo-action-pages-download legend", text: "pages.download", count: 0
    assert_select "input[name='embargo[fallback]'][value='preview']"
    assert_includes response.body, "2026-11-02T09:00"
  end

  test "saving updates the embargo and an invalid release is rejected" do
    sign_in @owner
    release = 4.days.from_now.change(sec: 0)

    patch recording_studio_embargo.recording_embargo_path(@page), params: embargo_params(
      lifts_at: release.strftime("%Y-%m-%dT%H:%M"),
      time_zone: "America/Chicago",
      fallback: "hidden",
      early_access: { "pages.show" => "signed_in", "pages.download" => "granted" }
    )

    assert_redirected_to recording_studio_embargo.edit_recording_embargo_path(@page)
    follow_redirect!
    assert_includes response.body, "Embargo saved"
    embargo = @page.reload.current_embargo
    assert_equal "America/Chicago", embargo.time_zone
    assert_equal "hidden", embargo.fallback
    assert_equal "signed_in", embargo.early_access_for(SHOW)
    assert embargo.active?

    patch recording_studio_embargo.recording_embargo_path(@page), params: embargo_params(
      lifts_at: 2.days.ago.strftime("%Y-%m-%dT%H:%M")
    )

    assert_response :unprocessable_entity
    assert_includes response.body, "future"
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
    assert_response :success
    assert_equal "preview", response.body
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

  def embargo_params(lifts_at:, time_zone: "America/New_York", fallback: "preview", early_access: nil)
    {
      embargo: {
        enabled: "1",
        lifts_at: lifts_at,
        time_zone: time_zone,
        fallback: fallback,
        early_access: early_access || { "pages.show" => "granted", "pages.download" => "granted" }
      }
    }
  end
end
