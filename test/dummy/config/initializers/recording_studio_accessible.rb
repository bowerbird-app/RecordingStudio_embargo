# frozen_string_literal: true

RecordingStudioAccessible.configure do |config|
  config.access_actor_types = [ "User" ]
  config.action_audiences[:"pages.show"] = {
    allowed: %i[public signed_in granted],
    default: :public,
    granted_roles: %i[view edit admin],
    granted_override: false,
    manage_role: :edit
  }
  config.action_audiences[:"pages.download"] = {
    allowed: %i[public signed_in granted],
    default: :public,
    granted_roles: %i[edit admin],
    granted_override: true,
    manage_role: :edit
  }
end

RecordingStudioAccessible.install_action_audience_policies!
