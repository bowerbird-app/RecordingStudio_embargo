# frozen_string_literal: true

require "test_helper"

class RestrictionUnitTest < Minitest::Test
  FakeEmbargo = Struct.new(:enabled, :lifts_at, :early_access, keyword_init: true) do
    def enabled?
      enabled
    end

    def active?(at = Time.current)
      enabled && lifts_at.present? && lifts_at > at
    end

    def early_access_for(action)
      early_access.to_h[action.to_s]
    end
  end

  FakeRecording = Struct.new(:current_embargo, :trashed_at)

  def test_inactive_and_unnamed_actions_are_not_applicable
    recording = FakeRecording.new(
      FakeEmbargo.new(enabled: false, lifts_at: 1.hour.from_now, early_access: { "pages.show" => "granted" }),
      nil
    )

    assert_equal :not_applicable, RecordingStudioEmbargo.restriction_for(
      recording: recording, action: :"pages.show", actor: nil
    )

    active = FakeRecording.new(
      FakeEmbargo.new(enabled: true, lifts_at: 1.hour.from_now, early_access: { "pages.show" => "granted" }),
      nil
    )
    assert_equal :not_applicable, RecordingStudioEmbargo.restriction_for(
      recording: active, action: :"pages.other", actor: nil
    )
  end

  def test_an_active_embargo_fails_closed_without_accessible
    skip "Accessible is loaded in this process" if defined?(RecordingStudioAccessible::AudienceResolver)

    recording = FakeRecording.new(
      FakeEmbargo.new(enabled: true, lifts_at: 1.hour.from_now, early_access: { "pages.show" => "public" }),
      nil
    )

    assert_equal :deny, RecordingStudioEmbargo.restriction_for(
      recording: recording, action: :"pages.show", actor: nil
    )
  end

  def test_a_trashed_recording_is_denied_while_the_embargo_is_active
    recording = FakeRecording.new(
      FakeEmbargo.new(enabled: true, lifts_at: 1.hour.from_now, early_access: { "pages.show" => "public" }),
      Time.current
    )

    assert_equal :deny, RecordingStudioEmbargo.restriction_for(
      recording: recording, action: :"pages.show", actor: Object.new
    )
  end

  def test_expiry_is_a_time_read
    lifts_at = Time.current
    recording = FakeRecording.new(
      FakeEmbargo.new(enabled: true, lifts_at: lifts_at, early_access: { "pages.show" => "granted" }),
      nil
    )

    assert_equal :not_applicable, RecordingStudioEmbargo.restriction_for(
      recording: recording, action: :"pages.show", actor: nil, at: lifts_at
    )
  end
end
