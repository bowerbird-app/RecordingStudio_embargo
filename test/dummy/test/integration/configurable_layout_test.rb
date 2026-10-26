# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class ConfigurableLayoutTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @previous_layout = RecordingStudioEmbargo.configuration.layout
    @previous_core_layout = RecordingStudio.configuration.layout
    @owner = User.create!(
      email: "layout-owner-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
    workspace = Workspace.create!(name: "Layout #{SecureRandom.hex(4)}")
    root = RecordingStudio.root_recording_for(workspace)
    @page = root.record(Page, actor: @owner, parent_recording: root) do |page|
      page.title = "Layout page #{SecureRandom.hex(4)}"
    end
    RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor: @owner)
  end

  teardown do
    RecordingStudioEmbargo.configuration.layout = @previous_layout
    RecordingStudio.configuration.layout = @previous_core_layout
    Current.actor = nil
  end

  test "nil falls through to the core layout and then the default shell" do
    assert_nil RecordingStudioEmbargo.configuration.layout
    controller = RecordingStudioEmbargo::EmbargoesController.new

    assert_equal "recording_studio/default_layout", controller.send(:recording_studio_resolved_layout)

    RecordingStudio.configuration.layout = "application"

    assert_equal "application", controller.send(:recording_studio_resolved_layout)
  end

  test "a string layout name wraps the editor" do
    RecordingStudioEmbargo.configuration.layout = "application"
    sign_in @owner

    get recording_studio_embargo.edit_recording_embargo_path(@page)

    assert_response :success
    assert_includes response.body, "embargo-form"
    assert_includes response.body, "<html"
    assert_select "body[data-recording-studio-default-layout]", count: 0
  end

  test "a keyword layout callable wraps the editor" do
    RecordingStudioEmbargo.configuration.layout = lambda do |controller:|
      raise "wrong controller" unless controller.is_a?(RecordingStudioEmbargo::EmbargoesController)

      "application"
    end
    sign_in @owner

    get recording_studio_embargo.edit_recording_embargo_path(@page)

    assert_response :success
    assert_includes response.body, "embargo-form"
    assert_select "body[data-recording-studio-default-layout]", count: 0
  end

  test "false renders the editor without a document layout" do
    RecordingStudioEmbargo.configuration.layout = false
    RecordingStudio.configuration.layout = "recording_studio/default_layout"
    sign_in @owner

    get recording_studio_embargo.edit_recording_embargo_path(@page)

    assert_response :success
    assert_includes response.body, "embargo-form"
    refute_match(/<html/i, response.body)
    assert_select "body[data-recording-studio-default-layout]", count: 0
  end

  test "a layout callable that returns a non-layout raises" do
    RecordingStudioEmbargo.configuration.layout = ->(controller:) { 1 }
    sign_in @owner

    error = assert_raises(ArgumentError) do
      get recording_studio_embargo.edit_recording_embargo_path(@page)
    end

    assert_includes error.message, "layout callable must return"
  end
end
