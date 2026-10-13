# frozen_string_literal: true

module RecordingStudioEmbargo
  # Cache identity for embargoed responses. Shared caches must not store a
  # public body for an actor-specific early-access response, and an entry must
  # not outlive lifts_at. Expiry itself does not depend on this helper.
  module Cache
    module_function

    def key(recording, actor, action, at: Time.current)
      embargo = Restriction.embargo_for(recording)
      [
        "recording_studio_embargo",
        recording&.id,
        action.to_s,
        actor_token(actor),
        *embargo_parts(embargo),
        Restriction.for(recording: recording, action: action, actor: actor, at: at)
      ]
    end

    def embargo_parts(embargo)
      lifts_at = embargo&.lifts_at
      [embargo&.id, embargo&.enabled?, lifts_at&.utc&.iso8601]
    end

    def expires_in(recording, at: Time.current)
      embargo = Restriction.embargo_for(recording)
      return nil unless embargo&.active?(at)

      seconds = embargo.lifts_at - at
      seconds.positive? ? seconds : 0
    end

    def actor_token(actor)
      return "anonymous" if actor.blank?

      "#{actor.class.name}:#{actor.id}"
    end
  end
end
