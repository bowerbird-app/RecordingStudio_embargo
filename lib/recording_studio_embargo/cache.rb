# frozen_string_literal: true

module RecordingStudioEmbargo
  # Identity of the stored embargo. Expiry is separate and does not change the key.
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
