class Page < ApplicationRecord
  recording_studio_recordable label: "Page", root: false, allowed_parent_types: [ "Workspace", "Folder" ]
  RecordingStudio.enable_capability(:action_audiences, on: self) if defined?(RecordingStudioAccessible)
  include RecordingStudio::Capabilities::Embargo.to(
    actions: [
      {
        action: :"pages.show",
        label: "View the page",
        description: "Who can open this page before the release time."
      },
      {
        action: :"pages.download",
        label: "Download the page",
        description: "Who can download before the release time. A view grant does not include this."
      }
    ],
    fallbacks: %w[preview hidden],
    manage_role: :edit
  )
end
