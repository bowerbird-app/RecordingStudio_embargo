# frozen_string_literal: true

module RecordingStudioEmbargo
  # Host-facing composition. Publishable, when the recording implements it,
  # decides whether the record is live. Accessible decides the baseline
  # audience. An active embargo can only narrow that baseline.
  module Composition
    PRESENTATIONS = %i[full preview hidden unavailable].freeze

    module_function

    # rubocop:disable-next Metrics/ParameterLists
    def action_permitted?(recording:, action:, actor:, context: {}, purpose: :public, at: Time.current)
      return false if recording.blank? || Restriction.trashed?(recording)
      return false if purpose.to_sym == :public && publication_withheld?(recording, at)
      return false if Restriction.for(recording: recording, action: action, actor: actor, context: context,
                                      at: at) == :deny

      baseline_permitted?(recording: recording, action: action, actor: actor, context: context)
    end

    # rubocop:disable-next Metrics/ParameterLists
    def presskit_presentation(recording:, actor:, view_action:, purpose: :public, normal_fallback: :preview,
                              at: Time.current)
      return :unavailable if recording.blank? || Restriction.trashed?(recording)
      return unpublished_presentation(actor, recording, purpose) unless published?(recording, at)
      return normalize_fallback(normal_fallback) if embargo_denies?(recording, actor, view_action, at)
      return :full if baseline_permitted?(recording: recording, action: view_action, actor: actor, context: {})

      normalize_fallback(normal_fallback)
    end

    def unpublished_presentation(actor, recording, purpose)
      return :full if purpose.to_sym == :editor && editor?(actor, recording)

      :unavailable
    end

    def embargo_denies?(recording, actor, action, at)
      Restriction.for(recording: recording, action: action, actor: actor, at: at) == :deny
    end

    def published?(recording, at = Time.current)
      return true unless recording.respond_to?(:currently_published?)

      recording.currently_published?(at)
    rescue ArgumentError
      recording.currently_published?
    end

    def publication_withheld?(recording, at)
      return false unless recording.respond_to?(:currently_published?)

      !published?(recording, at)
    end

    def baseline_permitted?(recording:, action:, actor:, context:)
      return false unless defined?(RecordingStudioAccessible)

      RecordingStudioAccessible.authorized_action?(
        actor: actor,
        action: action.to_sym,
        recording: recording,
        context: context
      )
    rescue StandardError
      false
    end

    def editor?(actor, recording)
      return false unless defined?(RecordingStudioAccessible)
      return false if actor.blank?

      RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :view)
    rescue StandardError
      false
    end

    def normalize_fallback(value)
      name = value.to_s.to_sym
      return name if %i[preview hidden].include?(name)

      :preview
    end
  end
end
