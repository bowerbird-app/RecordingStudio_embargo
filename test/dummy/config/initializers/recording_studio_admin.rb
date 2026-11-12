# frozen_string_literal: true

return unless defined?(RecordingStudioAdmin)

RecordingStudioAdmin.configure do |config|
  config.authentication_method = :authenticate_user!
  config.current_actor_method = :current_user
  config.access_recording_resolver = lambda do |context|
    controller = context.controller
    next unless controller.respond_to?(:current_root_recording, true)

    controller.send(:current_root_recording)
  end
end
