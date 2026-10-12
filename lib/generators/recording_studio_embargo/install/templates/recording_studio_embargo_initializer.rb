# frozen_string_literal: true

# RecordingStudioEmbargo does not turn itself on for every recordable.
# Opt in on the types that may carry an embargo, and list the actions the
# editor is allowed to restrict. Those actions must already exist as
# Accessible action audiences.
#
#   class Page < ApplicationRecord
#     include RecordingStudio::Capabilities::Embargo.to(
#       actions: [
#         { action: :"pages.show", label: "View the page", description: "Who can open the page before release." },
#         :"pages.download"
#       ],
#       fallbacks: %w[preview hidden],
#       manage_role: :edit
#     )
#   end

RecordingStudioEmbargo.configure do |config|
  # config.default_time_zone = "UTC"
  # config.manage_role = :edit
  # config.layout = "recording_studio/default_layout"
end
