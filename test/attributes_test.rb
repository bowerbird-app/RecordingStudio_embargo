# frozen_string_literal: true

require "test_helper"

class AttributesTest < Minitest::Test
  def setup
    I18n.load_path << File.expand_path("../config/locales/en.yml", __dir__)
    I18n.backend.reload!
  end

  FakeEmbargo = Struct.new(:enabled, :lifts_at, :time_zone, :accepts_early_access_requests, keyword_init: true) do
    def enabled?
      enabled
    end

    def accepts_early_access_requests?
      accepts_early_access_requests
    end
  end

  FakeParent = Struct.new(:current_embargo)

  def test_parses_a_zone_local_timestamp_to_utc
    parent = FakeParent.new(nil)
    parsed = RecordingStudioEmbargo::Attributes.parse(
      parent_recording: parent,
      raw: {
        enabled: "1",
        lifts_at: "2026-07-04T09:00",
        time_zone: "America/New_York",
        accepts_early_access_requests: "1"
      }
    )

    assert_equal true, parsed[:enabled]
    assert_equal Time.utc(2026, 7, 4, 13, 0, 0), parsed[:lifts_at]
    assert_equal "America/New_York", parsed[:time_zone]
    assert_equal true, parsed[:accepts_early_access_requests]
  end

  def test_spring_forward_gap_is_rejected
    parent = FakeParent.new(nil)

    error = assert_raises(RecordingStudioEmbargo::Invalid) do
      RecordingStudioEmbargo::Attributes.parse(
        parent_recording: parent,
        raw: { lifts_at: "2026-03-08 02:30", time_zone: "America/New_York" }
      )
    end

    assert_includes error.message, "YYYY-MM-DD HH:MM"
  end

  def test_parses_iso8601_z_as_the_named_instant
    parsed = RecordingStudioEmbargo::Attributes.parse(
      parent_recording: FakeParent.new(nil),
      raw: { lifts_at: "2026-12-01T01:00:00Z", time_zone: "Asia/Manila" }
    )

    assert_equal Time.utc(2026, 12, 1, 1, 0, 0), parsed[:lifts_at]
  end

  def test_parses_iso8601_offset_as_the_named_instant
    parsed = RecordingStudioEmbargo::Attributes.parse(
      parent_recording: FakeParent.new(nil),
      raw: { lifts_at: "2026-12-01T09:00:00+08:00", time_zone: "Asia/Manila" }
    )

    assert_equal Time.utc(2026, 12, 1, 1, 0, 0), parsed[:lifts_at]
  end

  def test_offset_instant_in_dst_gap_is_accepted
    parsed = RecordingStudioEmbargo::Attributes.parse(
      parent_recording: FakeParent.new(nil),
      raw: { lifts_at: "2026-03-08T02:30:00-05:00", time_zone: "America/New_York" }
    )

    assert_equal Time.utc(2026, 3, 8, 7, 30, 0), parsed[:lifts_at]
  end

  def test_parses_a_zoneless_wall_time_in_time_zone
    parsed = RecordingStudioEmbargo::Attributes.parse(
      parent_recording: FakeParent.new(nil),
      raw: { lifts_at: "2026-12-01 09:00", time_zone: "Asia/Manila" }
    )

    assert_equal Time.utc(2026, 12, 1, 1, 0, 0), parsed[:lifts_at]
  end

  def test_invalid_lifts_at_string_is_rejected
    error = assert_raises(RecordingStudioEmbargo::Invalid) do
      RecordingStudioEmbargo::Attributes.parse(
        parent_recording: FakeParent.new(nil),
        raw: { lifts_at: "not-a-date", time_zone: "Asia/Manila" }
      )
    end

    assert_includes error.message, "ISO 8601"
    refute_includes error.message, "future"
  end

  def test_weekday_phrase_is_rejected_as_invalid_not_past
    error = assert_raises(RecordingStudioEmbargo::Invalid) do
      RecordingStudioEmbargo::Attributes.parse(
        parent_recording: FakeParent.new(nil),
        raw: { lifts_at: "next tuesday", time_zone: "UTC" }
      )
    end

    assert_includes error.message, "ISO 8601"
    refute_includes error.message, "future"
  end

  def test_other_non_date_string_is_rejected_as_invalid_not_past
    error = assert_raises(RecordingStudioEmbargo::Invalid) do
      RecordingStudioEmbargo::Attributes.parse(
        parent_recording: FakeParent.new(nil),
        raw: { lifts_at: "Tuesday", time_zone: "UTC" }
      )
    end

    assert_includes error.message, "ISO 8601"
    refute_includes error.message, "future"
  end

  def test_partial_update_keeps_unspecified_fields
    current = FakeEmbargo.new(
      enabled: true,
      lifts_at: Time.utc(2026, 8, 1, 16, 0, 0),
      time_zone: "America/Chicago",
      accepts_early_access_requests: true
    )
    parent = FakeParent.new(current)

    parsed = RecordingStudioEmbargo::Attributes.parse(
      parent_recording: parent,
      raw: { accepts_early_access_requests: "0" }
    )

    assert_equal true, parsed[:enabled]
    assert_equal Time.utc(2026, 8, 1, 16, 0, 0), parsed[:lifts_at]
    assert_equal "America/Chicago", parsed[:time_zone]
    assert_equal false, parsed[:accepts_early_access_requests]
  end
end
