# frozen_string_literal: true

module RecordingStudioEmbargo
  # Identity of one embargo row: embargo id, enabled, and lifts_at.
  # The recording id is not part of the key. `key` passes `at:` through to
  # `stamp`, and `stamp` ignores it, so `at:` does not change the key.
  # Callers namespace the key with their own recording or resource identity.
  # Use `expires_in` for the TTL. `at:` on `expires_in` is the moment the
  # remaining time is measured from.
  module Cache
    module_function

    def key(recording, at: Time.current)
      embargo = embargo_for(recording)
      [
        embargo&.id,
        embargo&.enabled?,
        stamp(embargo&.lifts_at, at)
      ]
    end

    def expires_in(recording, at: Time.current)
      embargo = embargo_for(recording)
      return nil unless embargo&.active?(at)

      seconds = embargo.lifts_at - at
      seconds.positive? ? seconds : 0
    end

    def embargo_for(recording)
      return unless recording.respond_to?(:current_embargo)

      recording.current_embargo
    end

    def stamp(lifts_at, _at)
      lifts_at&.utc&.iso8601
    end
    private_class_method :embargo_for, :stamp
  end
end
