# frozen_string_literal: true

module RecordingStudioEmbargo
  module Services
    module Embargoes
      class Cancel < RecordingStudio::Services::BaseService
        def initialize(parent_recording:, actor: nil)
          super()
          @parent_recording = parent_recording
          @actor = actor
        end

        private

        attr_reader :parent_recording, :actor

        def perform
          current = parent_recording&.current_embargo
          return success(parent_recording&.embargo_child_recording) if current.blank? || !current.enabled?

          success(
            Upsert.call(
              parent_recording: parent_recording,
              attributes: { enabled: false },
              actor: actor
            ).value!
          )
        end

        def service_args
          { parent_recording_id: parent_recording&.id }
        end
      end
    end
  end
end
