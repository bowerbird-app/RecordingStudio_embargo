class Page < ApplicationRecord
  recording_studio_recordable label: "Page", root: false, allowed_parent_types: [ "Workspace", "Folder" ]
  RecordingStudio.enable_capability(:action_audiences, on: self) if defined?(RecordingStudioAccessible)
  include RecordingStudio::Capabilities::Embargo.to(
    actions: [ :"pages.show", :"pages.download" ],
    manage_role: :edit
  )
end
