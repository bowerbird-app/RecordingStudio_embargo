# frozen_string_literal: true

module RecordingStudioEmbargo
  module Api
    module Registration
      module_function

      def register!
        return unless recording_studio_api_available?

        RecordingStudioApi.configuration.each_api do |api_definition|
          ACTIONS.each { |action| register_action(action, api: api_definition.name) }
        end
      end

      def register_action(action, api:)
        name = action.fetch(:name)
        return if RecordingStudioApi.capability_action(name, api: api)

        RecordingStudioApi.register_capability_action(
          name,
          api: api,
          **capability_action_options(action)
        )
      end

      def capability_action_options(action)
        metadata(action).merge(
          handler: action.fetch(:handler),
          serializer: method(:serialize_recording),
          input_contract: input_contract_for(action.fetch(:input_fields)),
          openapi: action.fetch(:openapi)
        )
      end

      def metadata(action)
        {
          capability: :embargo,
          version: ACTION_VERSION,
          http_verb: action.fetch(:http_verb),
          scope: :member,
          required_role: RecordingStudioEmbargo.configuration.manage_role
        }
      end

      def serialize_recording(recording, **)
        MemberAction.serialize(recording)
      end

      def input_contract_for(fields)
        # Member actions still receive route params; RS_API does not strip them yet.
        { reject_unknown: false, fields: fields }
      end

      def recording_studio_api_available?
        defined?(RecordingStudioApi) &&
          RecordingStudioApi.respond_to?(:register_capability_action) &&
          RecordingStudioApi.respond_to?(:capability_action) &&
          RecordingStudioApi.respond_to?(:configuration) &&
          RecordingStudioApi.configuration.respond_to?(:each_api)
      end
    end
  end
end
