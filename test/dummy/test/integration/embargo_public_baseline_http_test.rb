# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"
require "active_job/test_helper"

class EmbargoPublicBaselineHttpTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  DOWNLOAD = :"pages.download"

  setup do
    @previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    @owner = create_user("owner")
    @granted = create_user("granted")
    @signed_in = create_user("signed-in")
    workspace = Workspace.create!(name: "Public baseline #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(workspace)
    @page = @root.record(Page, actor: @owner, parent_recording: @root) do |page|
      page.title = "Public page #{SecureRandom.hex(4)}"
    end
    RecordingStudioAccessible.bootstrap_owner_access!(recording: @root, actor: @owner)
    grant(@granted, :edit)
    RecordingStudioAccessible.set_audience!(
      recording: @page,
      action: DOWNLOAD,
      audience: :public,
      actor: @owner
    )
    @lifts_at = 2.days.from_now.change(usec: 0)
    @page.embargo_set!(
      {
        enabled: true,
        lifts_at: @lifts_at,
        time_zone: "UTC",
        early_access: { DOWNLOAD => "granted" },
        fallback: "hidden"
      },
      actor: @owner
    )
  end

  teardown do
    ActiveJob::Base.queue_adapter = @previous_adapter
    Current.actor = nil
  end

  test "an active embargo denies a public action until the release, with no job" do
    assert_equal :public, RecordingStudioAccessible.effective_audience(recording: @page, action: DOWNLOAD)

    assert_download :forbidden, actor: nil
    assert_download :forbidden, actor: @signed_in
    assert_download :success, actor: @granted

    travel_to(@lifts_at) do
      assert_download :success, actor: nil
      assert_download :success, actor: @signed_in
      assert_download :success, actor: @granted
    end

    assert_enqueued_jobs 1, only: RecordingStudioEmbargo::LiftTransitionJob
    assert_no_performed_jobs
    refute @page.embargo_child_recording.events.exists?(action: "embargo_lifted")
  end

  private

  def assert_download(status, actor:)
    actor ? sign_in(actor) : sign_out(:user)

    get embargo_sample_download_path(@page)

    assert_response status
    expected = status == :success ? "DOWNLOAD_OK" : "DOWNLOAD_DENIED"
    assert_equal expected, response.body
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
end