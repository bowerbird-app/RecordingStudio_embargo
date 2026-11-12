# frozen_string_literal: true

module RecordingStudioEmbargo
  module Api
    class ShowEmbargo
      def self.call(context)
        recording = MemberAction.scoped_recording!(context)
        MemberAction.authorize_management!(context, recording)
        recording
      end
    end
  end
end
