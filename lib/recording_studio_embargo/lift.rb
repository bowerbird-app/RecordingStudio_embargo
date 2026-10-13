# frozen_string_literal: true

require_relative "lift_transition_job"

module RecordingStudioEmbargo
  # The lift is a notification about a time that already passed. Authorization
  # does not call this. A job scheduled for an old lifts_at no-ops after a reschedule.
  module Lift
    module_function

    def enqueue(parent, current)
      return if current.blank? || !current.enabled || current.lifts_at.blank? || !current.lifts_at.future?
      return unless defined?(ActiveJob::Base)

      LiftTransitionJob.set(wait_until: current.lifts_at).perform_later(parent.id.to_s, current.lifts_at.iso8601(6))
    end

    def emit_if_due!(parent_recording_id:, expected_lifts_at:)
      parent = RecordingStudio::Recording.find_by(id: parent_recording_id)
      return if parent.blank?

      embargo = parent.current_embargo
      expected = parse_time(expected_lifts_at)
      return unless due?(embargo, expected)

      record_lift!(parent, expected)
    end

    def due?(embargo, expected)
      return false unless embargo&.enabled? && expected && embargo.lifts_at
      return false unless times_match?(embargo.lifts_at, expected)

      Time.current >= embargo.lifts_at
    end

    def times_match?(actual, expected)
      return false if actual.blank? || expected.blank?

      actual.utc.to_i == expected.utc.to_i
    end

    def parse_time(value)
      return value.utc if value.respond_to?(:utc) && !value.is_a?(String)
      return if value.blank?

      Time.zone.parse(value.to_s)&.utc
    rescue StandardError
      nil
    end

    def record_lift!(parent, expected)
      child = parent.embargo_child_recording
      key = "embargo-lifted-#{expected.utc.iso8601(6)}"
      return if child.event_by_idempotency_key(key)

      child.log_event!(action: "embargo_lifted", metadata: lift_metadata(expected), idempotency_key: key)
      notify_lift(parent)
    end

    def lift_metadata(expected)
      { "source" => "recording_studio_embargo.lift", "lifts_at" => expected.iso8601 }
    end

    def notify_lift(parent)
      Lifecycle.emit_after_commit(
        :embargo_lifted,
        Lifecycle.payload_for(parent, nil, Lifecycle.snapshot_for(parent), nil, "scheduled")
      )
    end
  end
end
