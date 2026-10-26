# frozen_string_literal: true

# RecordingStudioEmbargo does not turn itself on for every recordable.
# Opt in on the types that may carry an embargo, and list the actions the
# editor is allowed to restrict. Those actions must already exist as
# Accessible action audiences.
#
#   class Page < ApplicationRecord
#     include RecordingStudio::Capabilities::Embargo.to(
#       actions: [:"pages.show", :"pages.download"],
#       manage_role: :edit
#     )
#   end

RecordingStudioEmbargo.configure do |config|
  # config.default_time_zone = "UTC"
  # config.manage_role = :edit
  # nil follows RecordingStudio.configuration.layout, then the default shell.
  # config.layout = nil
  # Page refresh on the recording's Turbo stream after a change or a scheduled lift.
  # config.broadcast_page_refresh = true
end
