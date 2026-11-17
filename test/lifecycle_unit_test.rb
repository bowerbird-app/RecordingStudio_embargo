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
    current = snapshot(enabled: true, lifts_at: "2026-08-01T16:00:00Z", accepts_early_access_requests: false)

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

  def test_duplicate_attributes_keep_the_window_without_an_actor
    lifts_at = Time.utc(2027, 8, 1, 16, 0, 0)
    embargo = Struct.new(:enabled, :lifts_at, :time_zone, :accepts_early_access_requests) do
      def enabled?
        enabled
      end

      def accepts_early_access_requests?
        accepts_early_access_requests
      end

      def active?(at = Time.current)
        enabled? && lifts_at > at
      end
    end.new(true, lifts_at, "UTC", true)

    attributes = RecordingStudioEmbargo.attributes_for_duplicate(embargo, actor: nil)

    assert_equal true, attributes[:enabled]
    assert_equal lifts_at, attributes[:lifts_at]
    assert_equal "UTC", attributes[:time_zone]
    assert_equal true, attributes[:accepts_early_access_requests]
  end

  private

  def snapshot(enabled:, lifts_at:, accepts_early_access_requests: true)
    Snapshot.new(
      embargo_id: "embargo",
      enabled: enabled,
      lifts_at: Time.iso8601(lifts_at),
      time_zone: "UTC",
      accepts_early_access_requests: accepts_early_access_requests,
      fingerprint: [enabled, lifts_at, accepts_early_access_requests].join("|")
    )
  end
end
