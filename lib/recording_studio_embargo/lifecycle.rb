# frozen_string_literal: true

require_relative "lifecycle_snapshot"
require_relative "lifecycle_support"
require_relative "lift"

module RecordingStudioEmbargo
  # Config changes and the moment an embargo lifts are different events.
  # Authorization never waits for the lift event.
  module Lifecycle
    NAMESPACE = "recording_studio_embargo"
    SCHEMA_VERSION = 1
    EVENTS = {
      embargo_created: "embargo_created.#{NAMESPACE}",
      embargo_updated: "embargo_updated.#{NAMESPACE}",
      embargo_cancelled: "embargo_cancelled.#{NAMESPACE}",
      embargo_lifted: "embargo_lifted.#{NAMESPACE}"
    }.freeze

    Snapshot = LifecycleSnapshot

    module_function

    def subscribe(name, &block)
      event_name = event_name_for(name)
      ActiveSupport::Notifications.subscribe(event_name) do |*args|
        block.arity == 1 ? block.call(ActiveSupport::Notifications::Event.new(*args)) : block.call(*args)
      end
    end

    def event_name_for(name)
      value = name.to_s
      return value if EVENTS.value?(value)

      EVENTS.fetch(name.to_sym)
    end

    def snapshot_for(parent_recording)
      embargo = parent_recording&.current_embargo
      return if embargo.blank?

      build_snapshot(embargo)
    end

    def event_for(previous, current)
      return :embargo_created if previous.nil? && current
      return if unchanged?(previous, current)

      cancelled?(previous, current) ? :embargo_cancelled : :embargo_updated
    end

    def after_write!(parent_recording:, previous:, actor:, embargo_recording:)
      parent_recording.reload
      current = snapshot_for(parent_recording)
      Lift.enqueue(parent_recording, current)
      event = event_for(previous, current)
      return if event.nil?

      emit_after_commit(event, LifecycleSupport.payload_for(parent_recording, previous, current, actor, "write"))
      LifecycleSupport.record_history!(embargo_recording, event, actor, current)
    end

    def emit_lift_if_due!(...)
      Lift.emit_if_due!(...)
    end

    def payload_for(...)
      LifecycleSupport.payload_for(...)
    end

    def emit_after_commit(event, payload)
      if defined?(ActiveRecord) && ActiveRecord.respond_to?(:after_all_transactions_commit)
        ActiveRecord.after_all_transactions_commit { instrument!(event, payload) }
      else
        instrument!(event, payload)
      end
    end

    def instrument!(event, payload)
      ActiveSupport::Notifications.instrument(EVENTS.fetch(event), payload)
    end

    def build_snapshot(embargo)
      LifecycleSupport.build_snapshot(embargo)
    end

    def unchanged?(previous, current)
      previous.nil? || current.nil? || previous.fingerprint == current.fingerprint
    end

    def cancelled?(previous, current)
      previous.enabled && !current.enabled
    end
  end
end
