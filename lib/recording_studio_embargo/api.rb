# frozen_string_literal: true

require "recording_studio_embargo/api/member_action"
require "recording_studio_embargo/api/set_embargo"
require "recording_studio_embargo/api/cancel_embargo"
require "recording_studio_embargo/api/show_embargo"
require "recording_studio_embargo/api/actions"
require "recording_studio_embargo/api/registration"

module RecordingStudioEmbargo
  module Api
    ACTION_VERSION = "1.0.0"
    INTERNAL_ROUTE_PARAMETER_KEYS = %i[api_key api_version].push("api_key", "api_version").freeze

    def self.register_capability_actions!
      Registration.register!
    end
  end
end
