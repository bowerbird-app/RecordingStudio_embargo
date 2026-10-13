# frozen_string_literal: true

module RecordingStudioEmbargo
  # Time-of-check decision for one host-listed action.
  #
  # :allow means early access is on and the actor satisfies Accessible's
  # :granted audience for that action. A view grant does not satisfy an
  # action whose granted roles are edit or admin.
  #
  # :deny is absolute while the embargo is active, including when the
  # baseline audience is :public. This is not `baseline && early_access`:
  # a public baseline is true for every actor, so AND-ing it would let the
  # public audience bypass the embargo. Early access off denies every actor.
  module Restriction
    module_function

    def for(recording:, action:, actor:, context: {}, at: Time.current)
      embargo = embargo_for(recording)
      return :not_applicable unless applies?(embargo, recording, action, at)
      return :deny if trashed?(recording) || !embargo.early_access?

      granted?(recording, action, actor, context) ? :allow : :deny
    end

    def embargo_for(recording)
      return unless recording.respond_to?(:current_embargo)

      recording.current_embargo
    end

    def applies?(embargo, recording, action, at)
      embargo&.active?(at) && listed?(recording, action)
    end

    def listed?(recording, action)
      RecordingStudioEmbargo.configuration.actions_for(recording).map(&:to_s).include?(action.to_s)
    end

    def trashed?(recording)
      return false unless recording.respond_to?(:trashed_at)

      recording.trashed_at.present?
    end

    def granted?(recording, action, actor, context)
      return false unless defined?(RecordingStudioAccessible::AudienceAuthorization)
      return false unless granted_allowed?(recording, action)

      pass_granted?(recording, action, actor, context)
    rescue StandardError
      false
    end

    def granted_allowed?(recording, action)
      resolver = RecordingStudioAccessible::AudienceResolver
      return false unless resolver.configured?(action.to_sym)

      resolver.allowed_audiences_for(recording: recording, action: action.to_sym).include?(:granted)
    end

    def pass_granted?(recording, action, actor, context)
      RecordingStudioAccessible::AudienceAuthorization.audience_passes?(
        :granted,
        actor: actor,
        recording: recording,
        context: context.to_h.merge(action: action.to_sym)
      )
    end
  end
end
