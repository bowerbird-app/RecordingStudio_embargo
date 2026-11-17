# frozen_string_literal: true

require "test_helper"

class CopyPolicyTest < Minitest::Test
  def setup
    RecordingStudio::Gates.reset!
  end

  def teardown
    RecordingStudio::Gates.reset!
  end

  def test_a_missing_actor_keeps_the_window_when_the_gate_would_allow
    RecordingStudio.register_gate("embargo.manage", "copy.allow") { true }

    attributes = RecordingStudioEmbargo.attributes_for_duplicate(window, recording: Object.new, actor: nil)

    assert_equal true, attributes[:enabled]
    assert_equal window.lifts_at, attributes[:lifts_at]
    assert_equal "Pacific/Auckland", attributes[:time_zone]
    assert_equal true, attributes[:accepts_early_access_requests]
    refute attributes.key?(:early_access)
  end

  def test_an_actor_who_fails_the_gate_keeps_the_window
    RecordingStudio.register_gate("embargo.manage", "copy.deny") { false }

    attributes = RecordingStudioEmbargo.attributes_for_duplicate(window, recording: Object.new, actor: Object.new)

    assert_equal true, attributes[:enabled]
    assert_equal window.lifts_at, attributes[:lifts_at]
    assert_equal "Pacific/Auckland", attributes[:time_zone]
    assert_equal true, attributes[:accepts_early_access_requests]
  end

  def test_an_actor_who_passes_the_gate_clears_the_window
    allowed = Object.new
    RecordingStudio.register_gate("embargo.manage", "copy.owner") do |actor:, **|
      actor.equal?(allowed)
    end

    cleared = RecordingStudioEmbargo.attributes_for_duplicate(window, recording: Object.new, actor: allowed)

    assert_equal false, cleared[:enabled]
    assert_nil cleared[:lifts_at]
    assert_equal false, cleared[:accepts_early_access_requests]
  end

  def test_a_passing_actor_without_the_source_recording_keeps_the_window
    RecordingStudio.register_gate("embargo.manage", "copy.allow") { true }

    attributes = RecordingStudioEmbargo.attributes_for_duplicate(window, actor: Object.new)

    assert_equal window.lifts_at, attributes[:lifts_at]
    assert_equal true, attributes[:enabled]
  end

  private

  def window
    @window ||= Struct.new(:enabled, :lifts_at, :time_zone, :accepts_early_access_requests) do
      def enabled?
        enabled
      end

      def accepts_early_access_requests?
        accepts_early_access_requests
      end
    end.new(true, Time.utc(2026, 8, 1, 16, 0, 0), "Pacific/Auckland", true)
  end
end
