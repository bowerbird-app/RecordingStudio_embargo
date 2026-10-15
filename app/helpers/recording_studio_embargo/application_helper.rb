# frozen_string_literal: true

module RecordingStudioEmbargo
  module ApplicationHelper
    def render_embargo_button(recording, turbo_frame: nil)
      render RecordingStudioEmbargo::EmbargoButton::Component.new(
        recording: recording,
        turbo_frame: turbo_frame
      )
    end
  end
end
