# frozen_string_literal: true

module RecordingStudioEmbargo
  module ApplicationHelper
    def render_embargo_button(recording)
      render RecordingStudioEmbargo::EmbargoButton::Component.new(recording: recording)
    end
  end
end
