# frozen_string_literal: true

module RecordingStudioEmbargo
  module Api
    module MemberAction
      module_function

      def scoped_recording!(context)
        recording_id = context.recording&.id
        found = context.access_grant.accessible_recordings.find_by(id: recording_id)
        return found if found

        raise RecordingStudioApi::NotFoundError, "Recording was not found in this API scope"
      end

      def authorize_management!(context, recording)
        context.access_grant.authorize!(
          recording: recording,
          role: RecordingStudioEmbargo.configuration.manage_role_for(recording)
        )
      end

      def embargo_params(context)
        context.params.to_h.each_with_object({}) do |(key, value), filtered|
          symbol = key.to_sym
          filtered[symbol] = value if Attributes::KEYS.include?(symbol)
        end
      end

      def serialize(recording, **)
        embargo = recording.current_embargo
        {
          enabled: embargo&.enabled || false,
          lifts_at: embargo&.lifts_at,
          time_zone: embargo&.time_zone,
          early_access: embargo&.early_access || false,
          active: recording.embargo_active?
        }
      end
    end
  end
end
