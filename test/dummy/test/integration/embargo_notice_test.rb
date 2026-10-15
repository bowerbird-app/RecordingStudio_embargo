# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class EmbargoNoticeTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @owner = create_user("notice-owner")
    workspace = Workspace.create!(name: "Notice #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(workspace)
    @page = @root.record(Page, actor: @owner, parent_recording: @root) do |page|
      page.title = "Notice page #{SecureRandom.hex(4)}"
    end
    RecordingStudioAccessible.bootstrap_owner_access!(recording: @root, actor: @owner)
    @zone = ActiveSupport::TimeZone["Australia/Sydney"]
    @lifts_at = @zone.local(2026, 3, 12, 9, 0, 0)
  end

  teardown do
    Current.actor = nil
    I18n.reload!
  end

  test "an active embargo shows the notice in the embargo time zone" do
    sign_in @owner

    travel_to(@zone.local(2026, 3, 1, 8, 0, 0)) do
      activate!
      Time.use_zone("UTC") do
        get root_path(recording_id: @page.id)
      end
    end

    md = notice_html("embargo-notice-md")
    sm = notice_html("embargo-notice-sm")

    assert_notice md, icon_size: "w-6 h-6", title_class: "font-bold text-[var(--surface-content-color)]", subtitle_class: "text-sm"
    refute_includes md, "text-xs"
    refute_includes md, 'role="alert"'

    assert_notice sm, icon_size: "w-4 h-4", title_class: "font-bold text-sm", subtitle_class: "text-xs"
    assert_includes sm, "embargo-notice"
    refute_includes sm, "11 Mar 2026"
    refute_includes sm, "UTC"
  end

  test "no embargo renders nothing" do
    sign_in @owner

    get root_path(recording_id: @page.id)

    assert_empty notice_html("embargo-notice-md")
    assert_empty notice_html("embargo-notice-sm")
    refute_includes response.body, "Embargoed until"
    refute_includes response.body, "Not for publication until embargo lifts."
  end

  test "a disabled embargo renders nothing" do
    @page.embargo_set!(
      { enabled: false, lifts_at: nil, time_zone: "Australia/Sydney", early_access: false },
      actor: @owner
    )
    sign_in @owner

    get root_path(recording_id: @page.id)

    assert_empty notice_html("embargo-notice-md")
    refute_includes response.body, "Embargoed until"
  end

  test "an expired embargo renders nothing" do
    travel_to(@zone.local(2026, 3, 1, 8, 0, 0)) { activate! }
    sign_in @owner

    travel_to(@lifts_at) do
      get root_path(recording_id: @page.id)
    end

    assert_empty notice_html("embargo-notice-md")
    refute_includes response.body, "Embargoed until"
  end

  test "hosts can override the notice copy and time format" do
    travel_to(@zone.local(2026, 3, 1, 8, 0, 0)) { activate! }
    I18n.t("recording_studio_embargo.notice.title", time: "x")
    I18n.backend.store_translations(
      :en,
      recording_studio_embargo: {
        notice: {
          title: "Held until %{time}",
          subtitle: "Wait for the release.",
          time_format: "%Y"
        }
      }
    )
    sign_in @owner

    travel_to(@zone.local(2026, 3, 1, 8, 0, 0)) do
      get root_path(recording_id: @page.id)
    end

    html = notice_html("embargo-notice-md")
    assert_includes html, "Held until 2026"
    assert_includes html, "Wait for the release."
    refute_includes html, "Embargoed until"
    refute_includes html, "AEDT"
  end

  test "size must be sm or md" do
    error = assert_raises(ArgumentError) do
      RecordingStudioEmbargo::EmbargoNotice::Component.new(recording: @page, size: :xl)
    end

    assert_includes error.message, "Invalid size"
  end

  test "the home page renders the helper for both sizes" do
    source = Rails.root.join("app/views/home/index.html.erb").read

    assert_includes source, 'render_embargo_notice(@page_recording, id: "embargo-notice-md", class: "embargo-notice")'
    assert_includes source, 'render_embargo_notice(@page_recording, size: :sm, id: "embargo-notice-sm", class: "embargo-notice")'
    assert_includes ApplicationHelper.instance_methods, :render_embargo_notice
  end

  private

  def assert_notice(html, icon_size:, title_class:, subtitle_class:)
    assert_includes html, "Embargoed until 12 Mar 2026, 9:00 AM AEDT"
    assert_includes html, "Not for publication until embargo lifts."
    assert_includes html, "border-2"
    assert_includes html, "rounded-[var(--radius-lg)]"
    assert_includes html, "w-fit"
    assert_includes html, 'data-style="default"'
    assert_includes html, 'data-flat-pack--icon-name-value="lock-closed"'
    assert_includes html, 'aria-hidden="true"'
    assert_includes html, icon_size
    assert_includes html, title_class
    assert_includes html, subtitle_class
    assert_includes html, "text-[var(--surface-muted-content-color)]"
    assert_includes html, "embargo-notice"
    refute_includes html, "shadow-"
    refute_includes html, 'role="alert"'
  end

  def notice_html(id)
    Nokogiri::HTML(response.body).at_css("##{id}")&.to_html.to_s
  end

  def create_user(prefix)
    User.create!(
      email: "#{prefix}-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
  end

  def activate!
    @page.embargo_set!(
      { enabled: true, lifts_at: @lifts_at, time_zone: "Australia/Sydney", early_access: false },
      actor: @owner
    )
  end
end
