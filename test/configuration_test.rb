# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioEmbargo::Configuration.new
  end

  def test_merge_updates_known_attributes
    @configuration.merge!(default_time_zone: "America/Chicago", manage_role: :admin, layout: "application",
                          broadcast_page_refresh: false)

    assert_equal "America/Chicago", @configuration.default_time_zone
    assert_equal :admin, @configuration.manage_role
    assert_equal "application", @configuration.layout
    assert_equal false, @configuration.broadcast_page_refresh
  end

  def test_merge_ignores_unknown_keys
    @configuration.merge!(unknown_key: "ignored", manage_role: :view)

    refute_respond_to @configuration, :unknown_key
    assert_equal :view, @configuration.manage_role
  end

  def test_merge_with_non_enumerable_is_noop
    original = @configuration.to_h

    @configuration.merge!(nil)

    assert_equal original[:default_time_zone], @configuration.default_time_zone
    assert_equal original[:manage_role], @configuration.manage_role
    assert_equal original[:layout], @configuration.layout
  end

  def test_initialize_uses_zone_and_edit_role
    configuration = RecordingStudioEmbargo::Configuration.new

    assert_equal "UTC", configuration.default_time_zone
    assert_equal :edit, configuration.manage_role
    assert_equal true, configuration.broadcast_page_refresh
    assert_equal "recording_studio/default_layout", configuration.layout
    assert_instance_of RecordingStudio::Hooks, configuration.hooks
  end

  def test_merge_accepts_string_keys
    @configuration.merge!("default_time_zone" => "Europe/London", "manage_role" => "admin")

    assert_equal "Europe/London", @configuration.default_time_zone
    assert_equal "admin", @configuration.manage_role
  end

  def test_to_h_reports_registered_hook_counts
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.after_initialize { nil }

    result = @configuration.to_h

    assert_equal 2, result.fetch(:hooks_registered).fetch(:before_initialize)
    assert_equal 1, result.fetch(:hooks_registered).fetch(:after_initialize)
  end

  def test_configure_without_block_is_safe
    RecordingStudioEmbargo.configure

    assert_kind_of RecordingStudioEmbargo::Configuration, RecordingStudioEmbargo.configuration
  end

  def test_management_authorizer_fails_closed_without_an_actor
    recording = Object.new

    refute @configuration.authorize_management?(recording: recording, actor: nil)
  end
end
