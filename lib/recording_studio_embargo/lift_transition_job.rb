# frozen_string_literal: true

require "active_job"

module RecordingStudioEmbargo
  class LiftTransitionJob < ActiveJob::Base
    queue_as :default

    def perform(parent_recording_id, expected_lifts_at)
      Lifecycle.emit_lift_if_due!(
        parent_recording_id: parent_recording_id,
        expected_lifts_at: expected_lifts_at
      )
    end
  end
end
