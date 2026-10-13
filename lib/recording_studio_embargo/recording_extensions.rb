# frozen_string_literal: true

module RecordingStudioEmbargo
  module RecordingExtensions
    def embargo_child_recording
      return unless respond_to?(:child_recordings)

      relation = child_recordings.of_type(RecordingStudioEmbargo::Embargo)
      relation = relation.where(trashed_at: nil) if relation.respond_to?(:where) && trashed_column?
      relation.first
    end

    def current_embargo
      embargo_child_recording&.recordable
    end

    def embargo_active?(at = Time.current)
      current_embargo&.active?(at) || false
    end

    def embargo_set!(attributes, actor: nil)
      Services::Embargoes::Upsert.call(
        parent_recording: self,
        attributes: attributes,
        actor: actor
      ).value!
    end

    def embargo_cancel!(actor: nil)
      Services::Embargoes::Cancel.call(parent_recording: self, actor: actor).value!
    end

    def embargo_history
      child = embargo_child_recording
      return RecordingStudio::Event.none unless child

      child.events.order(occurred_at: :asc, created_at: :asc)
    end

    private

    def trashed_column?
      RecordingStudio::Recording.column_names.include?("trashed_at")
    rescue StandardError
      false
    end
  end
end
