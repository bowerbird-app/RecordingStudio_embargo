# frozen_string_literal: true

module RecordingStudioEmbargo
  module LifecycleSupport
    module_function

    def fingerprint_for(embargo)
      lifts_at = embargo.lifts_at
      [
        embargo.enabled?,
        lifts_at&.utc&.iso8601,
        embargo.time_zone,
        embargo.early_access?
      ].join("|")
    end

    def payload_for(parent, previous, current, actor, source)
      recording_payload(parent).merge(actor_payload(actor), state_payload(previous, current, source))
    end

    def build_snapshot(embargo)
      Lifecycle::Snapshot.new(
        embargo_id: embargo.id,
        enabled: embargo.enabled?,
        lifts_at: embargo.lifts_at,
        time_zone: embargo.time_zone,
        early_access: embargo.early_access?,
        fingerprint: fingerprint_for(embargo)
      )
    end

    def record_history!(embargo_recording, event, actor, current)
      return if embargo_recording.blank?

      embargo_recording.log_event(
        action: event.to_s,
        actor: actor,
        metadata: history_metadata(event, current),
        idempotency_key: history_key(event, current)
      )
    end

    def recording_payload(parent)
      {
        schema_version: Lifecycle::SCHEMA_VERSION,
        recording_id: parent.id,
        recordable_type: parent.recordable_type,
        recordable_id: parent.recordable_id
      }
    end

    def actor_payload(actor)
      actor_identifier = actor.respond_to?(:id) ? actor.id : nil
      { actor_type: actor&.class&.name, actor_id: actor_identifier }
    end

    def state_payload(previous, current, source)
      {
        previous_state: previous&.to_payload,
        current_state: current&.to_payload,
        occurred_at: Time.current,
        source: source
      }
    end

    def history_metadata(event, current)
      lifts_at = current&.lifts_at
      {
        "source" => "recording_studio_embargo.write",
        "lifecycle" => event.to_s,
        "lifts_at" => lifts_at&.iso8601
      }
    end

    def history_key(event, current)
      "embargo-write-#{event}-#{current&.embargo_id}-#{current&.fingerprint}"
    end
  end
end
