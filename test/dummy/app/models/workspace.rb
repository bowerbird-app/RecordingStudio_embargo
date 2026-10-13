class Workspace < ApplicationRecord
  recording_studio_recordable label: "Workspace", root: true
  if defined?(RecordingStudioAccessible)
    RecordingStudio.enable_capability(:accessible, on: self)
    RecordingStudio.enable_capability(:action_audiences, on: self)
  end
end
