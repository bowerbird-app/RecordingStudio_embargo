# frozen_string_literal: true

require "test_helper"

class EmbargoCapabilityTest < Minitest::Test
  module Probe
    HostType = Class.new
    OtherType = Class.new
  end

  def setup
    @original_capabilities =
      RecordingStudio.configuration.instance_variable_get(:@capabilities).transform_values(&:dup)
    @original_capability_options =
      RecordingStudio.configuration.instance_variable_get(:@capability_options).dup
  end

  def teardown
    RecordingStudio.configuration.instance_variable_set(:@capabilities, @original_capabilities)
    RecordingStudio.configuration.instance_variable_set(:@capability_options, @original_capability_options)
  end

  def test_to_is_the_include_for_wrapper
    source = File.read(File.expand_path("../../lib/recording_studio/capabilities/embargo.rb", __dir__))

    assert_includes source, "def self.to(actions: [], fallbacks: [], manage_role: :edit)"
    assert_includes source, "RecordingStudio::Capabilities.include_for(:embargo, **options)"
    refute_includes source, "enable_capability"
    refute_includes source, "set_capability_options"
  end

  def test_including_to_enables_the_capability_and_stores_actions
    Probe::HostType.include RecordingStudio::Capabilities::Embargo.to(
      actions: %i[pages.show pages.download],
      fallbacks: %w[preview hidden],
      manage_role: :admin
    )

    assert RecordingStudio.capability_enabled?(:embargo, for: Probe::HostType)
    refute RecordingStudio.capability_enabled?(:embargo, for: Probe::OtherType)
    assert_equal(
      {
        actions: %i[pages.show pages.download],
        fallbacks: %w[preview hidden],
        manage_role: :admin
      },
      RecordingStudio.capability_options(:embargo, for: Probe::HostType)
    )
  end
end
