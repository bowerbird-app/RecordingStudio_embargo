# frozen_string_literal: true

module RecordingStudio
  module Capabilities
    module Embargo
      CHILD_TYPE = "RecordingStudioEmbargo::Embargo"

      def self.included(base)
        RecordingStudio.enable_capability(:embargo, on: base)
        ensure_child_recordable_registered!
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
