# frozen_string_literal: true

require_relative "../../app/helpers/recording_studio_embargo/application_helper"

module RecordingStudioEmbargo
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioEmbargo
    paths.add "app/components", eager_load: true

    initializer "recording_studio_embargo.view_helpers" do
      ActiveSupport.on_load(:action_view) do
        include RecordingStudioEmbargo::ApplicationHelper
      end
    end

    initializer "recording_studio_embargo.before_initialize",
                before: "recording_studio_embargo.load_config" do |_app|
      RecordingStudioEmbargo.configuration.hooks.run(:before_initialize, self)
    end

    initializer "recording_studio_embargo.load_config" do |app|
      if app.respond_to?(:config_for)
        yaml = begin
          app.config_for(:recording_studio_embargo)
        rescue StandardError
          nil
        end
        RecordingStudioEmbargo.configuration.merge!(yaml) if yaml.respond_to?(:each)
      end

      if app.config.respond_to?(:x) && app.config.x.respond_to?(:recording_studio_embargo)
        xcfg = app.config.x.recording_studio_embargo
        RecordingStudioEmbargo.configuration.merge!(xcfg.to_h) if xcfg.respond_to?(:to_h)
      end

      RecordingStudioEmbargo.configuration.hooks.run(:on_configuration, RecordingStudioEmbargo.configuration)
    rescue StandardError
      nil
    end

    initializer "recording_studio_embargo.after_initialize",
                after: "recording_studio_embargo.load_config" do |_app|
      RecordingStudioEmbargo.configuration.hooks.run(:after_initialize, self)
    end

    initializer "recording_studio_embargo.extensions" do
      config.to_prepare do
        RecordingStudioEmbargo.install!
      end
    end
  end
end
