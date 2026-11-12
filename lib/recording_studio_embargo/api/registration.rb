# frozen_string_literal: true

module RecordingStudioEmbargo
  module Api
    module Registration
      KEYWORD_PARAMETER_TYPES = %i[key keyreq].freeze

      module_function

      def register!
        return unless recording_studio_api_available?

        if named_api_registration_supported?
          RecordingStudioApi.configuration.each_api do |api_definition|
            ACTIONS.each { |action| register_action(action, api: api_definition.name) }
          end
        else
          ACTIONS.each { |action| register_action(action) }
        end
      end

      def register_action(action, api: nil)
        name = action.fetch(:name)
        return if capability_action_registered?(name, api: api)

        options = capability_action_options(action)
        if api
          RecordingStudioApi.register_capability_action(name, api: api, **options)
        else
          RecordingStudioApi.register_capability_action(name, **options)
        end
      end

      def capability_action_registered?(name, api:)
        if api && action_api_accepts_api?(:capability_action)
          RecordingStudioApi.capability_action(name, api: api)
        else
          RecordingStudioApi.capability_action(name)
        end
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
        definition = { reject_unknown: true, fields: fields }
        return definition unless defined?(RecordingStudioApi::ActionInputContract)

        route_parameter_contract.new(definition)
      end

      def route_parameter_contract
        Class.new(RecordingStudioApi::ActionInputContract) do
          define_method(:call) do |raw_params|
            params = raw_params.respond_to?(:to_h) ? raw_params.to_h : raw_params
            params = params.except(*INTERNAL_ROUTE_PARAMETER_KEYS) if params.respond_to?(:except)
            super(params)
          end
        end
      end

      def named_api_registration_supported?
        RecordingStudioApi.respond_to?(:configuration) &&
          RecordingStudioApi.configuration.respond_to?(:each_api) &&
          action_api_accepts_api?(:capability_action) &&
          action_api_accepts_api?(:register_capability_action)
      end

      def action_api_accepts_api?(method_name)
        RecordingStudioApi.method(method_name).parameters.any? do |type, name|
          type == :keyrest || (name == :api && KEYWORD_PARAMETER_TYPES.include?(type))
        end
      end

      def recording_studio_api_available?
        defined?(RecordingStudioApi) &&
          RecordingStudioApi.respond_to?(:capability_action) &&
          RecordingStudioApi.respond_to?(:register_capability_action)
      end
    end
  end
end
