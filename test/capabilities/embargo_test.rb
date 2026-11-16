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

  def test_including_the_module_enables_embargo_without_an_action_list
    Probe::HostType.include RecordingStudio::Capabilities::Embargo

    assert RecordingStudio.capability_enabled?(:embargo, for: Probe::HostType)
    refute RecordingStudio.capability_enabled?(:embargo, for: Probe::OtherType)
    assert_nil RecordingStudio.capability_options(:embargo, for: Probe::HostType)
    refute_respond_to RecordingStudio::Capabilities::Embargo, :to
  end
end
