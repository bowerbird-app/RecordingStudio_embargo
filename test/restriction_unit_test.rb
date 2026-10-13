# frozen_string_literal: true

require "test_helper"

class RestrictionUnitTest < Minitest::Test
  FakeEmbargo = Struct.new(:enabled, :lifts_at, :early_access, keyword_init: true) do
    def enabled?
      enabled
    end

    def early_access?
      early_access
    end

    def active?(at = Time.current)
      enabled && lifts_at.present? && lifts_at > at
    end
  end

  FakeRecording = Struct.new(:current_embargo, :trashed_at)

  def test_inactive_and_unlisted_actions_are_not_applicable
    recording = FakeRecording.new(
      FakeEmbargo.new(enabled: false, lifts_at: 1.hour.from_now, early_access: true),
      nil
    )

    assert_equal :not_applicable, decision(recording, :"pages.show")

    active = FakeRecording.new(
      FakeEmbargo.new(enabled: true, lifts_at: 1.hour.from_now, early_access: true),
      nil
    )
    assert_equal :not_applicable, decision(active, :"pages.other")
  end

  def test_an_active_embargo_fails_closed_without_accessible
    skip "Accessible is loaded in this process" if defined?(RecordingStudioAccessible::AudienceResolver)

    recording = FakeRecording.new(
      FakeEmbargo.new(enabled: true, lifts_at: 1.hour.from_now, early_access: true),
      nil
    )

    assert_equal :deny, decision(recording, :"pages.show")
  end

  def test_early_access_off_denies_every_actor
    recording = FakeRecording.new(
      FakeEmbargo.new(enabled: true, lifts_at: 1.hour.from_now, early_access: false),
      nil
    )

    assert_equal :deny, decision(recording, :"pages.show", actor: Object.new)
  end

  def test_a_trashed_recording_is_denied_while_the_embargo_is_active
    recording = FakeRecording.new(
      FakeEmbargo.new(enabled: true, lifts_at: 1.hour.from_now, early_access: true),
      Time.current
    )

    assert_equal :deny, decision(recording, :"pages.show", actor: Object.new)
  end

  def test_expiry_is_a_time_read
    lifts_at = Time.current
    recording = FakeRecording.new(
      FakeEmbargo.new(enabled: true, lifts_at: lifts_at, early_access: true),
      nil
    )

    assert_equal :not_applicable, RecordingStudioEmbargo.restriction_for(
      recording: recording, action: :"pages.show", actor: nil, at: lifts_at
    )
  end

  private

  def decision(recording, action, actor: nil)
    RecordingStudioEmbargo.configuration.stub(:actions_for, [:"pages.show"]) do
      RecordingStudioEmbargo.restriction_for(recording: recording, action: action, actor: actor)
    end
  end
end
