# frozen_string_literal: true

module RecordingStudioEmbargo
  class Configuration
    attr_accessor :default_time_zone, :layout, :manage_role, :current_actor_resolver, :management_authorizer
    attr_reader :hooks

    def initialize
      @default_time_zone = default_rails_time_zone
      @layout = "recording_studio/default_layout"
      @manage_role = :edit
      @current_actor_resolver = method(:default_actor)
      @management_authorizer = method(:default_management_authorizer)
      @hooks = RecordingStudio::Hooks.new
    end

    def to_h
      {
        default_time_zone: default_time_zone,
        layout: layout,
        manage_role: manage_role,
        hooks_registered: hooks.instance_variable_get(:@registry).transform_values(&:size)
      }
    end

    def merge!(hash)
      return unless hash.respond_to?(:each)

      hash.each do |key, value|
        setter = "#{key}="
        public_send(setter, value) if respond_to?(setter)
      end
    end

    def actor_for(controller: nil)
      call_resolver(current_actor_resolver, controller: controller)
    end

    def authorize_management?(recording:, actor:, controller: nil)
      call_resolver(management_authorizer, recording: recording, actor: actor, controller: controller)
    end

    def manage_role_for(recording)
      options = capability_options_for(recording)
      role = options[:manage_role] if options.is_a?(Hash)
      (role.presence || manage_role).to_sym
    rescue StandardError
      manage_role.to_sym
    end

    def actions_for(recording)
      RecordingStudioEmbargo::ActionCatalog.keys_for(stored_actions(recording))
    end

    def action_definitions_for(recording)
      RecordingStudioEmbargo::ActionCatalog.definitions_for(stored_actions(recording))
    end

    def fallbacks_for(recording)
      Array(capability_options_for(recording)[:fallbacks]).map(&:to_s)
    rescue StandardError
      []
    end

    private

    def default_rails_time_zone
      return Time.zone.name if Time.zone

      "UTC"
    rescue StandardError
      "UTC"
    end

    def default_actor(controller: nil)
      from_controller = controller&.try(:current_user)
      return from_controller if from_controller.present?
      return Current.actor if defined?(Current) && Current.respond_to?(:actor)

      nil
    end

    def default_management_authorizer(recording:, actor:, controller: nil)
      actor ||= actor_for(controller: controller)
      return false if actor.blank? || recording.blank?
      return false unless defined?(RecordingStudioAccessible)

      RecordingStudioAccessible.authorized?(
        actor: actor,
        recording: recording,
        role: manage_role_for(recording)
      )
    rescue StandardError
      false
    end

    def stored_actions(recording)
      Array(capability_options_for(recording)[:actions])
    rescue StandardError
      []
    end

    def capability_options_for(recording)
      return {} unless defined?(RecordingStudio)
      return {} if recording.blank?

      type = recording.respond_to?(:recordable_type) ? recording.recordable_type : recording
      RecordingStudio.capability_options(:embargo, for: type) || {}
    end

    def call_resolver(resolver, **arguments)
      return resolver unless resolver.respond_to?(:call)

      resolver.call(**accepted_arguments(resolver, arguments))
    rescue StandardError
      false
    end

    def accepted_arguments(resolver, arguments)
      parameters = resolver.respond_to?(:parameters) ? resolver.parameters : []
      return arguments if parameters.any? { |type, _name| type == :keyrest }

      supported = parameters.filter_map { |type, name| name if %i[key keyreq].include?(type) }
      arguments.slice(*supported)
    end
  end
end
