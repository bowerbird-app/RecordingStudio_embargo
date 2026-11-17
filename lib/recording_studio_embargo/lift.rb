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

    def install_restore_hook!
      return if @restore_hook_installed

      hooks = RecordingStudio.configuration.hooks
      return unless hooks.respond_to?(:after_record)

      hooks.after_record { |event| after_restored(event) }
      @restore_hook_installed = true
    end

    # Recording.kept hides the embargo child while the parent is trashed, so the
    # job that runs at lifts_at records nothing. Trashable writes action
    # "restored" through record!, which runs this core hook. This gem does not
    # depend on Trashable, so the action name is the check.
    def after_restored(event)
      return unless restored_event?(event)

      recording_id = event.recording_id
      return if recording_id.blank?

      after_commit { reconcile_restored!(recording_id) }
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

      actor = stored_actor(child)
      child.log_event!(action: "embargo_lifted", actor: actor, metadata: lift_metadata(expected), idempotency_key: key)
      notify_lift(parent, actor)
    end

    def stored_actor(child)
      child.events.where.not(actor_id: nil).reorder(occurred_at: :desc, created_at: :desc).first&.actor
    end

    def lift_metadata(expected)
      { "source" => "recording_studio_embargo.lift", "lifts_at" => expected.iso8601 }
    end

    def notify_lift(parent, actor)
      Lifecycle.emit_after_commit(
        :embargo_lifted,
        Lifecycle.payload_for(parent, nil, Lifecycle.snapshot_for(parent), actor, "scheduled")
      )
    end

    def restored_event?(event)
      event.respond_to?(:action) && event.action == "restored" && event.respond_to?(:recording_id)
    end

    def after_commit(&block)
      if defined?(ActiveRecord) && ActiveRecord.respond_to?(:after_all_transactions_commit)
        ActiveRecord.after_all_transactions_commit(&block)
      else
        block.call
      end
    end

    def reconcile_restored!(recording_id)
      parent = RecordingStudio::Recording.find_by(id: recording_id)
      embargo = embargo_for(parent)
      return unless catch_up?(embargo)

      catch_up!(parent, embargo)
    end

    def embargo_for(parent)
      return unless parent.respond_to?(:current_embargo)

      parent.current_embargo
    end

    def catch_up?(embargo)
      embargo.present? && embargo.enabled? && embargo.lifts_at.present?
    end

    def catch_up!(parent, embargo)
      if Time.current >= embargo.lifts_at
        emit_if_due!(parent_recording_id: parent.id, expected_lifts_at: embargo.lifts_at)
      else
        enqueue(parent, embargo)
      end
    end
  end
end
