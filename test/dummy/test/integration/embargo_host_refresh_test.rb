# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class EmbargoHostRefreshTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include Turbo::Broadcastable::TestHelper

  setup do
    @owner = User.create!(
      email: "refresh-owner-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
    workspace = Workspace.create!(name: "Refresh #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(workspace)
    @page = @root.record(Page, actor: @owner, parent_recording: @root) do |page|
      page.title = "Refresh page #{SecureRandom.hex(4)}"
    end
    RecordingStudioAccessible.bootstrap_owner_access!(recording: @root, actor: @owner)
    @broadcasts = RecordingStudioEmbargo.configuration.broadcast_page_refresh
  end

  teardown do
    Current.actor = nil
    RecordingStudioEmbargo.configuration.broadcast_page_refresh = @broadcasts
  end

  test "a scheduled lift touches the parent and broadcasts a page refresh" do
    lifts_at = 2.hours.from_now.change(usec: 0)
    @page.embargo_set!(
      { enabled: true, lifts_at: lifts_at, time_zone: "UTC", early_access: false },
      actor: @owner
    )
    before = @page.reload.updated_at

    payloads = capture_turbo_stream_broadcasts(@page) do
      travel_to(lifts_at) do
        RecordingStudioEmbargo::LiftTransitionJob.perform_now(@page.id.to_s, lifts_at.iso8601(6))
      end
    end

    assert_operator @page.reload.updated_at, :>, before
    assert_refresh payloads
    assert @page.embargo_child_recording.events.exists?(action: "embargo_lifted")
  end

  test "turning off the broadcast still touches the parent on a lift" do
    RecordingStudioEmbargo.configuration.broadcast_page_refresh = false
    lifts_at = 2.hours.from_now.change(usec: 0)
    @page.embargo_set!(
      { enabled: true, lifts_at: lifts_at, time_zone: "UTC", early_access: false },
      actor: @owner
    )
    before = @page.reload.updated_at

    payloads = capture_turbo_stream_broadcasts(@page) do
      travel_to(lifts_at) do
        RecordingStudioEmbargo::LiftTransitionJob.perform_now(@page.id.to_s, lifts_at.iso8601(6))
      end
    end

    assert_operator @page.reload.updated_at, :>, before
    assert_empty payloads
  end

  test "saving broadcasts a refresh and does not target host markup" do
    sign_in @owner
    @page.embargo_set!(
      { enabled: true, lifts_at: 3.days.from_now, time_zone: "UTC", early_access: false },
      actor: @owner
    )

    payloads = capture_turbo_stream_broadcasts(@page) do
      patch recording_studio_embargo.recording_embargo_path(@page), params: {
        embargo: {
          enabled: "1",
          lifts_at: 5.days.from_now.strftime("%Y-%m-%dT%H:%M"),
          time_zone: "UTC",
          early_access: "0"
        }
      }
    end

    assert_refresh payloads
  end

  private

  def assert_refresh(payloads)
    assert_equal 1, payloads.size
    html = payloads.first.to_html
    assert_equal "refresh", payloads.first["action"]
    refute_includes html, "embargo-editor-modal"
    refute_includes html, "embargo_button"
    refute_includes html, "target="
  end
end
