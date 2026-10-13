# frozen_string_literal: true

module RecordingStudioEmbargo
  module Services
    module Embargoes
      class Upsert < RecordingStudio::Services::BaseService
        def initialize(parent_recording:, attributes:, actor: nil)
          super()
          @parent_recording = parent_recording
          @attributes = attributes
          @actor = actor
        end

        private

        attr_reader :parent_recording, :attributes, :actor

        def perform
          raise Unauthorized, Copy.t("errors.unauthorized") unless authorized?
          raise Invalid, Copy.t("errors.parent_required") if parent_recording.blank?

          success(persist!)
        end

        def persist!
          parsed = validated_attributes
          previous = Lifecycle.snapshot_for(parent_recording)
          embargo_recording = write!(parsed)
          record_lifecycle!(previous, embargo_recording)
          embargo_recording
        end

        def validated_attributes
          parsed = Attributes.parse(parent_recording: parent_recording, raw: attributes)
          validate!(parsed)
          parsed
        end

        def record_lifecycle!(previous, embargo_recording)
          Lifecycle.after_write!(
            parent_recording: parent_recording,
            previous: previous,
            actor: actor,
            embargo_recording: embargo_recording
          )
        end

        def validate!(parsed)
          candidate = editable_copy(parent_recording.current_embargo)
          Validator.call(parent_recording: parent_recording, embargo: candidate, attributes: parsed)
        end

        def write!(parsed)
          existing = parent_recording.embargo_child_recording
          return revise!(existing, parsed) if existing

          create!(parsed)
        end

        def revise!(existing, parsed)
          root.revise(existing, actor: actor, metadata: write_metadata) do |embargo|
            embargo.apply_configuration!(parsed)
          end
        end

        def create!(parsed)
          root.record(Embargo, actor: actor, parent_recording: parent_recording, metadata: write_metadata) do |embargo|
            embargo.apply_configuration!(parsed)
          end
        end

        def root
          parent_recording.root_recording || parent_recording
        end

        def write_metadata
          { "source" => "recording_studio_embargo.upsert" }
        end

        def editable_copy(embargo)
          if embargo.blank?
            return Embargo.new(
              enabled: false,
              early_access: false,
              time_zone: RecordingStudioEmbargo.configuration.default_time_zone
            )
          end

          Embargo.new(embargo.attributes.except("id", "created_at", "updated_at"))
        end

        def authorized?
          RecordingStudioEmbargo.configuration.authorize_management?(recording: parent_recording, actor: actor)
        end

        def service_args
          { parent_recording_id: parent_recording&.id }
        end
      end
    end
  end
end
