# frozen_string_literal: true

module RecordingStudioEmbargo
  class Validator
    def self.call(parent_recording:, embargo:, attributes:)
      new(parent_recording, embargo, attributes).call
    end

    def initialize(parent_recording, embargo, attributes)
      @parent_recording = parent_recording
      @embargo = embargo
      @attributes = attributes
    end

    def call
      embargo.apply_configuration!(attributes)
      raise Invalid, embargo.errors.full_messages.to_sentence unless embargo.valid?

      validate_actions!
      validate_audiences!
      validate_fallback!
    end

    private

    attr_reader :parent_recording, :embargo, :attributes

    def validate_actions!
      return if unknown_actions.empty?

      raise Invalid, Copy.t("errors.unknown_actions", actions: unknown_actions.join(", "))
    end

    def validate_audiences!
      embargo.early_access.each do |action, audience|
        validate_audience!(action, audience)
      end
    end

    def validate_audience!(action, audience)
      name = audience.to_sym
      unless registered_audience?(name)
        raise Invalid, Copy.t("errors.audience_unregistered", audience: audience, action: action)
      end
      return unless audience_configured?(action)
      return if allowed_audiences(action).include?(name)

      raise Invalid, Copy.t("errors.audience_not_allowed", audience: audience, action: action)
    end

    def validate_fallback!
      fallback = attributes[:fallback].to_s
      return if fallback.blank?

      allowed = RecordingStudioEmbargo.configuration.fallbacks_for(parent_recording)
      return if allowed.empty? || allowed.include?(fallback)

      raise Invalid, Copy.t("errors.fallback_not_allowed", fallback: fallback)
    end

    def unknown_actions
      configured = RecordingStudioEmbargo.configuration.actions_for(parent_recording).map(&:to_s)
      return [] if configured.empty?

      embargo.early_access.keys - configured
    end

    def registered_audience?(name)
      return true unless defined?(RecordingStudioAccessible)

      RecordingStudioAccessible.registered_audience?(name)
    end

    def audience_configured?(action)
      return false unless defined?(RecordingStudioAccessible::AudienceResolver)

      RecordingStudioAccessible::AudienceResolver.configured?(action.to_sym)
    end

    def allowed_audiences(action)
      RecordingStudioAccessible::AudienceResolver.allowed_audiences_for(
        recording: parent_recording,
        action: action.to_sym
      )
    end
  end
end
