# frozen_string_literal: true

require "test_helper"

class CopyPolicyTest < Minitest::Test
  def setup
    RecordingStudio::Gates.reset!
    @authorizer = RecordingStudioEmbargo.configuration.management_authorizer
    I18n.load_path |= [File.expand_path("../config/locales/en.yml", __dir__)]
    I18n.reload!
  end

  def teardown
    RecordingStudio::Gates.reset!
    RecordingStudioEmbargo.configuration.management_authorizer = @authorizer
  end

  def test_attributes_keep_the_window_for_a_missing_actor
    RecordingStudio.register_gate("embargo.manage", "copy.allow") { true }

    attributes = RecordingStudioEmbargo.attributes_for_duplicate(window, recording: Object.new, actor: nil)

    assert_equal true, attributes[:enabled]
    assert_equal window.lifts_at, attributes[:lifts_at]
    assert_equal "Pacific/Auckland", attributes[:time_zone]
    assert_equal true, attributes[:accepts_early_access_requests]
    refute attributes.key?(:early_access)
  end

  def test_an_actor_who_fails_the_gate_keeps_the_window
    allow_management!
    RecordingStudio.register_gate("embargo.manage", "copy.deny") { false }

    attributes = RecordingStudioEmbargo.attributes_for_duplicate(window, recording: Object.new, actor: Object.new)

    assert_equal true, attributes[:enabled]
    assert_equal window.lifts_at, attributes[:lifts_at]
    assert_equal "Pacific/Auckland", attributes[:time_zone]
    assert_equal true, attributes[:accepts_early_access_requests]
  end

  def test_an_actor_who_passes_the_gate_clears_the_window
    allowed = Object.new
    allow_management!
    RecordingStudio.register_gate("embargo.manage", "copy.owner") do |actor:, **|
      actor.equal?(allowed)
    end

    cleared = RecordingStudioEmbargo.attributes_for_duplicate(window, recording: Object.new, actor: allowed)

    assert_equal false, cleared[:enabled]
    assert_nil cleared[:lifts_at]
    assert_equal false, cleared[:accepts_early_access_requests]
  end

  def test_copy_onto_refuses_a_missing_actor_before_writing_an_active_window
    source = Struct.new(:current_embargo).new(window)
    copy = Object.new

    error = assert_raises(RecordingStudioEmbargo::Unauthorized) do
      RecordingStudioEmbargo.copy_onto!(source_recording: source, copy_recording: copy, actor: nil)
    end

    assert_equal "A person is required to copy an embargoed recording.", error.message
  end

  def test_copy_onto_with_a_missing_actor_does_nothing_without_an_embargo
    source = Struct.new(:current_embargo).new(nil)
    copy = Object.new

    result = RecordingStudioEmbargo.copy_onto!(source_recording: source, copy_recording: copy, actor: nil)

    assert_same copy, result
  end

  def test_copy_onto_with_a_missing_actor_does_nothing_after_the_window_lifts
    source = Struct.new(:current_embargo).new(window_at(Time.utc(2026, 1, 1, 12, 0, 0)))
    copy = Object.new

    result = RecordingStudioEmbargo.copy_onto!(source_recording: source, copy_recording: copy, actor: nil)

    assert_same copy, result
  end

  def test_a_lifted_window_is_not_copied
    lifted = window_at(Time.utc(2026, 1, 1, 12, 0, 0))

    attributes = RecordingStudioEmbargo.attributes_for_duplicate(lifted, recording: Object.new, actor: nil)

    assert_equal false, attributes[:enabled]
    assert_nil attributes[:lifts_at]
  end

  def test_a_passing_actor_without_the_source_recording_keeps_the_window
    RecordingStudio.register_gate("embargo.manage", "copy.allow") { true }

    attributes = RecordingStudioEmbargo.attributes_for_duplicate(window, actor: Object.new)

    assert_equal window.lifts_at, attributes[:lifts_at]
    assert_equal true, attributes[:enabled]
  end

  private

  def allow_management!
    RecordingStudioEmbargo.configuration.management_authorizer = ->(**) { true }
  end

  def window
    @window ||= window_at(Time.utc(2027, 8, 1, 16, 0, 0))
  end

  def window_at(lifts_at)
    Struct.new(:enabled, :lifts_at, :time_zone, :accepts_early_access_requests) do
      def enabled?
        enabled
      end

      def accepts_early_access_requests?
        accepts_early_access_requests
      end

      def active?(at = Time.current)
        enabled? && lifts_at > at
      end
    end.new(true, lifts_at, "Pacific/Auckland", true)
  end
end
