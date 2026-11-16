# frozen_string_literal: true

# RecordingStudioEmbargo does not turn itself on for every recordable.
# Opt in on the types that may carry an embargo. The gem stores the window.
# It does not decide who can see the recording.
#
#   class PressKit < ApplicationRecord
#     include RecordingStudio::Capabilities::Embargo
#   end

RecordingStudioEmbargo.configure do |config|
  # config.default_time_zone = "UTC"
  # config.manage_role = :edit
  # nil follows RecordingStudio.configuration.layout, then the default shell.
  # config.layout = nil
  # Page refresh on the recording's Turbo stream after a change or a scheduled lift.
  # config.broadcast_page_refresh = true
end
