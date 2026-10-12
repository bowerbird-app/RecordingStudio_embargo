# frozen_string_literal: true

require "test_helper"

class EngineTest < Minitest::Test
  def setup
    @original_configuration = RecordingStudioEmbargo.instance_variable_get(:@configuration)
    RecordingStudioEmbargo.instance_variable_set(:@configuration, RecordingStudioEmbargo::Configuration.new)
  end

  def teardown
    RecordingStudioEmbargo.configuration.hooks.clear!
    RecordingStudioEmbargo.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_before_and_after_initialize_initializers_run_hooks
    before_called = false
    after_called = false

    RecordingStudioEmbargo.configuration.hooks.before_initialize { |_engine| before_called = true }
    RecordingStudioEmbargo.configuration.hooks.after_initialize { |_engine| after_called = true }

    find_initializer("recording_studio_embargo.before_initialize").block.call(Object.new)
    find_initializer("recording_studio_embargo.after_initialize").block.call(Object.new)

    assert before_called
    assert after_called
  end

  def test_load_config_merges_yaml_and_rails_config
    hook_called = false
    RecordingStudioEmbargo.configuration.hooks.on_configuration { hook_called = true }

    xcfg = Class.new do
      def to_h
        { manage_role: :admin }
      end
    end.new
    app_config = Struct.new(:x).new(Struct.new(:recording_studio_embargo).new(xcfg))
    app = Struct.new(:config) do
      def config_for(_name)
        { default_time_zone: "Pacific/Auckland" }
      end
    end.new(app_config)

    find_initializer("recording_studio_embargo.load_config").block.call(app)

    assert hook_called
    assert_equal "Pacific/Auckland", RecordingStudioEmbargo.configuration.default_time_zone
    assert_equal :admin, RecordingStudioEmbargo.configuration.manage_role
  end

  def test_load_config_ignores_config_for_errors
    app = Struct.new(:config) do
      def config_for(_name)
        raise "missing yaml"
      end
    end.new(Struct.new(:x).new(nil))

    find_initializer("recording_studio_embargo.load_config").block.call(app)

    assert_equal :edit, RecordingStudioEmbargo.configuration.manage_role
  end

  private

  def find_initializer(name)
    RecordingStudioEmbargo::Engine.initializers.find { |entry| entry.name == name }
  end
end
