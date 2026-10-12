# frozen_string_literal: true

module RecordingStudioEmbargo
  # Time-of-check decision for one named action.
  #
  # :allow means the actor satisfies the embargo's early-access audience.
  # It does not grant the action. Hosts still enforce publication, the
  # baseline Accessible audience, and domain authorization.
  #
  # :deny is absolute for that action while the embargo is active, including
  # when the baseline audience is :public. This is not `baseline && early_access`:
  # a public baseline is true for every actor, so AND-ing it (or returning early
  # because authorized_action? succeeded) would let the public audience bypass
  # the embargo. Early access is evaluated as its own Accessible audience.
  module Restriction
    module_function

    def for(recording:, action:, actor:, context: {}, at: Time.current)
      embargo = embargo_for(recording)
      return :not_applicable unless active_for_action?(embargo, action, at)
      return :deny if trashed?(recording)

      audience = resolved_audience(recording, action, embargo)
      return :deny if audience.blank? || audience == :denied

      if satisfies?(audience, recording: recording, action: action, actor: actor, context: context)
        :allow
      else
        :deny
      end
    end

    def embargo_for(recording)
      return unless recording.respond_to?(:current_embargo)

      recording.current_embargo
    end

    def active_for_action?(embargo, action, at)
      return false unless embargo&.active?(at)

      embargo.early_access_for(action).present?
    end

    def trashed?(recording)
      return false unless recording.respond_to?(:trashed_at)

      recording.trashed_at.present?
    end

    def resolved_audience(recording, action, embargo)
      raw = embargo.early_access_for(action)
      return :denied if raw.blank?
      return :denied unless defined?(RecordingStudioAccessible::AudienceResolver)

      allowed_name(recording, action, raw.to_sym)
    end

    def allowed_name(recording, action, name)
      resolver = RecordingStudioAccessible::AudienceResolver
      return name unless resolver.configured?(action.to_sym)

      allowed = resolver.allowed_audiences_for(recording: recording, action: action.to_sym)
      return name if allowed.include?(name)
      return :granted if allowed.include?(:granted)

      :denied
    end

    def satisfies?(audience, recording:, action:, actor:, context:)
      return false unless defined?(RecordingStudioAccessible::AudienceAuthorization)

      eval_context = context.to_h.merge(action: action.to_sym)
      authorization = RecordingStudioAccessible::AudienceAuthorization
      return true if authorization.audience_passes?(audience, actor: actor, recording: recording, context: eval_context)
      return false unless RecordingStudioAccessible::AudienceResolver.granted_override?(action.to_sym)
      return false if audience.to_sym == :granted

      authorization.audience_passes?(:granted, actor: actor, recording: recording, context: eval_context)
    rescue StandardError
      false
    end
  end
end
