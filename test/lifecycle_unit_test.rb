# frozen_string_literal: true

require "test_helper"

class LifecycleUnitTest < Minitest::Test
  Snapshot = RecordingStudioEmbargo::Lifecycle::Snapshot

  def test_event_for_distinguishes_create_update_and_cancel
    created = snapshot(enabled: true, lifts_at: "2026-08-01T16:00:00Z")
    updated = snapshot(enabled: true, lifts_at: "2026-08-02T16:00:00Z")
    cancelled = snapshot(enabled: false, lifts_at: "2026-08-02T16:00:00Z")

    assert_equal :embargo_created, RecordingStudioEmbargo::Lifecycle.event_for(nil, created)
    assert_nil RecordingStudioEmbargo::Lifecycle.event_for(created, created)
    assert_equal :embargo_updated, RecordingStudioEmbargo::Lifecycle.event_for(created, updated)
    assert_equal :embargo_cancelled, RecordingStudioEmbargo::Lifecycle.event_for(updated, cancelled)
  end

  def test_a_config_write_never_chooses_the_lift_event
    previous = snapshot(enabled: true, lifts_at: "2026-08-01T16:00:00Z")
    current = snapshot(enabled: true, lifts_at: "2026-08-01T16:00:00Z", early_access: false)

    refute_equal :embargo_lifted, RecordingStudioEmbargo::Lifecycle.event_for(previous, current)
  end

  def test_lift_is_due_only_for_the_stored_instant
    embargo = Struct.new(:enabled, :lifts_at) do
      def enabled?
        enabled
      end
    end.new(true, Time.utc(2026, 8, 1, 16, 0, 0))

    Time.stub(:current, Time.utc(2026, 8, 1, 16, 0, 0)) do
      assert RecordingStudioEmbargo::Lift.due?(embargo, Time.utc(2026, 8, 1, 16, 0, 0))
      refute RecordingStudioEmbargo::Lift.due?(embargo, Time.utc(2026, 8, 1, 17, 0, 0))
    end

    Time.stub(:current, Time.utc(2026, 8, 1, 15, 59, 59)) do
      refute RecordingStudioEmbargo::Lift.due?(embargo, embargo.lifts_at)
    end
  end

  def test_duplicate_attributes_clear_activation
    attributes = RecordingStudioEmbargo.attributes_for_duplicate(Object.new)

    assert_equal false, attributes[:enabled]
    assert_nil attributes[:lifts_at]
    assert_equal false, attributes[:early_access]
  end

  private

  def snapshot(enabled:, lifts_at:, early_access: true)
    Snapshot.new(
      embargo_id: "embargo",
      enabled: enabled,
      lifts_at: Time.iso8601(lifts_at),
      time_zone: "UTC",
      early_access: early_access,
      fingerprint: [enabled, lifts_at, early_access].join("|")
    )
  end
end
