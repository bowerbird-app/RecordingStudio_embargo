# frozen_string_literal: true

require "test_helper"

class EmbargoLiftsAtTest < ActiveSupport::TestCase
  test "a weekday phrase is invalid before the future check" do
    embargo = RecordingStudioEmbargo::Embargo.new(
      enabled: true,
      lifts_at: "next tuesday",
      time_zone: "UTC"
    )

    refute embargo.valid?
    assert_includes embargo.errors[:lifts_at].join, "ISO 8601"
    refute_includes embargo.errors[:lifts_at].join, "future"
  end

  test "a junk string is invalid before the future check" do
    embargo = RecordingStudioEmbargo::Embargo.new(
      enabled: true,
      lifts_at: "whenever",
      time_zone: "UTC"
    )

    refute embargo.valid?
    assert_includes embargo.errors[:lifts_at].join, "ISO 8601"
    refute_includes embargo.errors[:lifts_at].join, "future"
  end

  test "a past ISO instant must be in the future" do
    embargo = RecordingStudioEmbargo::Embargo.new(
      enabled: true,
      lifts_at: 2.days.ago.utc.iso8601,
      time_zone: "UTC"
    )

    refute embargo.valid?
    assert_includes embargo.errors[:lifts_at].join, "future"
    refute_includes embargo.errors[:lifts_at].join, "ISO 8601"
  end
end
