# frozen_string_literal: true

module RecordingStudio
  module Capabilities
    module Embargo
      CHILD_TYPE = "RecordingStudioEmbargo::Embargo"

      def self.to(actions: [], fallbacks: [], manage_role: :edit)
        options = {
          actions: normalize_actions(actions),
          fallbacks: normalize_fallbacks(fallbacks),
          manage_role: manage_role.to_sym
        }
        RecordingStudio::Capabilities.include_for(:embargo, **options) do |_base|
          ensure_child_recordable_registered!
        end
      end

      def self.ensure_child_recordable_registered!
        return unless defined?(RecordingStudio::Recording)
        return unless RecordingStudio::Recording.respond_to?(:delegated_type)
        return if registered_type?

        RecordingStudio.register_recordable_type(CHILD_TYPE)
      end

      def self.registered_type?
        Array(RecordingStudio.configuration.recordable_types).map { |type| type.is_a?(Class) ? type.name : type.to_s }
                                                             .include?(CHILD_TYPE)
      end

      def self.normalize_actions(actions)
        Array(actions).filter_map { |action| action.to_s.strip.presence&.to_sym }.uniq
      end

      def self.normalize_fallbacks(fallbacks)
        Array(fallbacks).filter_map { |fallback| fallback.to_s.strip.presence }.uniq
      end

      module RecordingMethods
        include RecordingStudio::Capability if defined?(RecordingStudio::Capability)
        include RecordingStudioEmbargo::RecordingExtensions
      end
    end
  end
end

RecordingStudio.register_capability(
  :embargo,
  recording_methods: RecordingStudio::Capabilities::Embargo::RecordingMethods,
  source: "recording_studio_embargo",
  child_recordables: [RecordingStudio::Capabilities::Embargo::CHILD_TYPE]
)
