# frozen_string_literal: true

module RecordingStudioEmbargo
  class ApplicationController < (defined?(::ApplicationController) ? ::ApplicationController : ActionController::Base)
    protect_from_forgery with: :exception

    recording_studio_layout { RecordingStudioEmbargo.configuration.layout }
  end
end
