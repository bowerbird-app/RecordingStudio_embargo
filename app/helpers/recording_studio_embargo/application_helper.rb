# frozen_string_literal: true

module RecordingStudioEmbargo
  module ApplicationHelper
    def recording_studio_embargo_management_path(recording, return_to: nil)
      safe_return = RecordingStudioEmbargo::ReturnTo.path(return_to, request: request)
      options = {}
      options[:return_to] = safe_return if safe_return
      edit_embargo_path(recording, options)
    end

    def embargoed?(recording)
      RecordingStudioEmbargo.embargoed?(recording)
    end

    def render_embargo_notice(recording, **)
      render RecordingStudioEmbargo::EmbargoNotice::Component.new(recording: recording, **)
    end

    private

    def edit_embargo_path(recording, options)
      if respond_to?(:recording_studio_embargo)
        recording_studio_embargo.edit_recording_embargo_path(recording, options)
      else
        edit_recording_embargo_path(recording, options)
      end
    end
  end
end
