# frozen_string_literal: true

module RecordingStudioEmbargo
  # A copy keeps an active window unless the actor may manage the source.
  # That requires the Accessible manage role and `embargo.manage` on the
  # source recording. A missing actor may not clear. A window that has
  # already lifted is not copied. A missing actor is a system write: core
  # stores a nil actor only while `allow_unauthorized_writes` is on and
  # `require_actor` is off, so the copy turns those on for that write and
  # restores them.
  module CopyPolicy
    CLEARED = {
      enabled: false,
      lifts_at: nil,
      accepts_early_access_requests: false
    }.freeze

    module_function

    def attributes_for_duplicate(embargo = nil, recording: nil, actor: nil)
      return CLEARED if may_clear?(recording, actor)
      return CLEARED unless active_window?(embargo)

      window_attributes(embargo)
    end

    def copy_onto!(source_recording:, copy_recording:, actor: nil)
      attributes = attributes_for_duplicate(
        embargo_on(source_recording),
        recording: source_recording,
        actor: actor
      )
      write_copy!(copy_recording, attributes, actor)
      copy_recording
    end

    def may_clear?(recording, actor)
      return false if actor.nil? || recording.blank?

      manage_role?(recording, actor) && manage_gate?(recording, actor)
    end

    def manage_role?(recording, actor)
      RecordingStudioEmbargo.configuration.authorize_management?(recording: recording, actor: actor)
    end

    def manage_gate?(recording, actor)
      RecordingStudioEmbargo.manage_allowed?(recording: recording, actor: actor)
    end

    def embargo_on(recording)
      recording.current_embargo if recording.respond_to?(:current_embargo)
    end

    def active_window?(embargo)
      embargo.respond_to?(:active?) && embargo.active?(Time.current)
    end

    def window_attributes(embargo)
      {
        enabled: embargo.enabled? || false,
        lifts_at: embargo.lifts_at,
        time_zone: embargo.respond_to?(:time_zone) ? embargo.time_zone : nil,
        accepts_early_access_requests: early_access?(embargo)
      }
    end

    def early_access?(embargo)
      embargo.respond_to?(:accepts_early_access_requests?) && embargo.accepts_early_access_requests?
    end

    def write_copy!(copy_recording, attributes, actor)
      raise Invalid, Copy.t("errors.parent_required") if copy_recording.blank?
      return if attributes == CLEARED && embargo_on(copy_recording).blank?

      return CopySystemWrite.call { record_copy!(copy_recording, attributes, nil) } if actor.nil?

      record_copy!(copy_recording, attributes, actor)
    end

    def record_copy!(copy_recording, attributes, actor)
      parsed = Attributes.parse(parent_recording: copy_recording, raw: attributes)
      validate_copy!(copy_recording, parsed)
      previous = Lifecycle.snapshot_for(copy_recording)
      saved = save_copy!(copy_recording, parsed, actor)
      Lifecycle.after_write!(
        parent_recording: copy_recording, previous: previous, actor: actor, embargo_recording: saved
      )
    end

    def validate_copy!(copy_recording, parsed)
      Validator.call(parent_recording: copy_recording, embargo: validation_embargo(copy_recording), attributes: parsed)
    end

    def validation_embargo(copy_recording)
      current = embargo_on(copy_recording)
      return Embargo.new(current.attributes.except("id", "created_at", "updated_at")) if current

      Embargo.new(
        enabled: false,
        accepts_early_access_requests: false,
        time_zone: RecordingStudioEmbargo.configuration.default_time_zone
      )
    end

    def save_copy!(copy_recording, parsed, actor)
      root = copy_recording.root_recording || copy_recording
      copy_recording.with_lock do
        existing = embargo_child(copy_recording)
        existing ? revise_copy!(root, existing, parsed, actor) : create_copy!(root, copy_recording, parsed, actor)
      end
    end

    def embargo_child(recording)
      recording.embargo_child_recording if recording.respond_to?(:embargo_child_recording)
    end

    def revise_copy!(root, existing, parsed, actor)
      root.revise(existing, actor: actor, metadata: copy_metadata) do |embargo|
        embargo.apply_configuration!(parsed)
      end
    end

    def create_copy!(root, copy_recording, parsed, actor)
      root.record(Embargo, actor: actor, parent_recording: copy_recording, metadata: copy_metadata) do |embargo|
        embargo.apply_configuration!(parsed)
      end
    end

    def copy_metadata
      { "source" => "recording_studio_embargo.copy" }
    end
  end

  # Core stores a nil actor only when unauthorized writes are allowed and an
  # actor is not required. This wraps that one copy write, then puts the
  # host settings back.
  module CopySystemWrite
    module_function

    def call
      configuration = RecordingStudio.configuration
      saved = settings(configuration)
      apply(configuration)
      yield
    ensure
      restore(configuration, saved)
    end

    def settings(configuration)
      {
        allow_unauthorized_writes: configuration.allow_unauthorized_writes,
        require_actor: configuration.require_actor,
        authorize_write: configuration.authorize_write,
        actor: configuration.actor
      }
    end

    def apply(configuration)
      configuration.allow_unauthorized_writes = true
      configuration.require_actor = false
      configuration.actor = -> {}
      configuration.authorize_write = ->(**) { true }
    end

    def restore(configuration, saved)
      return if configuration.nil? || saved.nil?

      configuration.allow_unauthorized_writes = saved.fetch(:allow_unauthorized_writes)
      configuration.require_actor = saved.fetch(:require_actor)
      configuration.actor = saved.fetch(:actor)
      configuration.authorize_write = saved.fetch(:authorize_write)
    end
  end
end
