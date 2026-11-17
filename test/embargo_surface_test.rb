# frozen_string_literal: true

require "test_helper"

class EmbargoSurfaceTest < Minitest::Test
  FakeEmbargo = Struct.new(:id, :enabled, :lifts_at, :accepts_early_access_requests, keyword_init: true) do
    def enabled?
      enabled
    end

    def accepts_early_access_requests?
      accepts_early_access_requests
    end

    def active?(at = Time.current)
      enabled? && lifts_at.present? && lifts_at > at
    end
  end

  FakeRecording = Struct.new(:current_embargo)

  def test_removed_visibility_api_is_gone
    refute RecordingStudioEmbargo.const_defined?(:Restriction)
    refute RecordingStudioEmbargo.const_defined?(:Composition)
    refute_respond_to RecordingStudioEmbargo, :restriction_for
    refute_respond_to RecordingStudioEmbargo, :action_permitted?
    refute_respond_to RecordingStudioEmbargo, :presskit_presentation
    refute_respond_to RecordingStudio::Capabilities::Embargo, :to
    refute_respond_to RecordingStudioEmbargo.configuration, :actions_for
  end

  def test_upsert_no_longer_accepts_a_manage_gate_bypass
    error = assert_raises(ArgumentError) do
      RecordingStudioEmbargo::Services::Embargoes::Upsert.new(
        parent_recording: Object.new,
        attributes: {},
        check_manage_gate: false
      )
    end

    assert_includes error.message, "check_manage_gate"
  end

  def test_cache_key_is_the_same_whoever_asks
    lifts_at = Time.utc(2026, 8, 1, 16, 0, 0)
    embargo = FakeEmbargo.new(id: "embargo-1", enabled: true, lifts_at: lifts_at, accepts_early_access_requests: true)
    recording = FakeRecording.new(embargo)
    at = Time.utc(2026, 8, 1, 12, 0, 0)
    anonymous = RecordingStudioEmbargo::Cache.key(recording, at: at)
    later = RecordingStudioEmbargo.cache_key(recording, at: at + 60)

    assert_equal [embargo.id, true, lifts_at.iso8601], anonymous
    assert_equal anonymous, later
    refute_includes anonymous, nil
    refute_includes anonymous, :deny
    assert_in_delta 4.hours, RecordingStudioEmbargo::Cache.expires_in(recording, at: at), 1
    assert_nil RecordingStudioEmbargo::Cache.expires_in(recording, at: lifts_at)
  end

  def test_copy_helpers_are_gone
    refute RecordingStudioEmbargo.const_defined?(:CopyPolicy)
    refute_respond_to RecordingStudioEmbargo, :copy_onto!
    refute_respond_to RecordingStudioEmbargo, :attributes_for_duplicate
    assert_respond_to RecordingStudioEmbargo, :can_manage?
  end

  def test_create_migration_stores_the_renamed_column
    root = File.expand_path("..", __dir__)
    migration = File.read(File.join(root, "db/migrate/20261012130000_create_recording_studio_embargo_embargoes.rb"))

    assert_includes migration, "t.boolean :accepts_early_access_requests, null: false, default: false"
    refute_includes migration, ":early_access,"
  end
end
