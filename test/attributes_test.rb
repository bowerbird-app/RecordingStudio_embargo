# frozen_string_literal: true

require "test_helper"

class AttributesTest < Minitest::Test
  def setup
    I18n.load_path << File.expand_path("../config/locales/en.yml", __dir__)
    I18n.backend.reload!
  end

  FakeEmbargo = Struct.new(:enabled, :lifts_at, :time_zone, :early_access, :fallback, keyword_init: true) do
    def enabled?
      enabled
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
        early_access: { "pages.show" => "granted" },
        fallback: "preview"
      }
    )

    assert_equal true, parsed[:enabled]
    assert_equal Time.utc(2026, 7, 4, 13, 0, 0), parsed[:lifts_at]
    assert_equal "America/New_York", parsed[:time_zone]
    assert_equal({ "pages.show" => "granted" }, parsed[:early_access])
    assert_equal "preview", parsed[:fallback]
  end

  def test_spring_forward_gap_is_rejected
    parent = FakeParent.new(nil)

    error = assert_raises(RecordingStudioEmbargo::Invalid) do
      RecordingStudioEmbargo::Attributes.parse(
        parent_recording: parent,
        raw: { lifts_at: "2026-03-08 02:30", time_zone: "America/New_York" }
      )
    end

    assert_includes error.message, "real release date"
  end

  def test_partial_update_keeps_unspecified_fields
    current = FakeEmbargo.new(
      enabled: true,
      lifts_at: Time.utc(2026, 8, 1, 16, 0, 0),
      time_zone: "America/Chicago",
      early_access: { "pages.show" => "signed_in" },
      fallback: "hidden"
    )
    parent = FakeParent.new(current)

    parsed = RecordingStudioEmbargo::Attributes.parse(parent_recording: parent, raw: { fallback: "preview" })

    assert_equal true, parsed[:enabled]
    assert_equal Time.utc(2026, 8, 1, 16, 0, 0), parsed[:lifts_at]
    assert_equal "America/Chicago", parsed[:time_zone]
    assert_equal({ "pages.show" => "signed_in" }, parsed[:early_access])
    assert_equal "preview", parsed[:fallback]
  end
end
