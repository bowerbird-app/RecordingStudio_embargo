# frozen_string_literal: true

module RecordingStudioEmbargo
  module Api
    class CancelEmbargo
      def self.call(context)
        recording = MemberAction.scoped_recording!(context)
        MemberAction.authorize_management!(context, recording)
        recording.embargo_cancel!(actor: context.access_grant.actor)
        recording
      rescue Unauthorized => e
        raise RecordingStudioApi::AuthorizationError, e.message
      rescue Invalid => e
        raise RecordingStudioApi::InvalidActionInputError.new(e.message, details: [e.message])
      end
    end
  end
end
