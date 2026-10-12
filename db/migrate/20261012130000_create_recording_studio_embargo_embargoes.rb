# frozen_string_literal: true

class CreateRecordingStudioEmbargoEmbargoes < ActiveRecord::Migration[8.1]
  RECORDABLE_TYPE = "RecordingStudioEmbargo::Embargo"
  CHILD_INDEX = "index_rs_embargo_child_per_parent"

  def change
    create_table :recording_studio_embargo_embargoes, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.boolean :enabled, null: false, default: false
      t.datetime :lifts_at
      t.string :time_zone, null: false, default: "UTC"
      t.jsonb :early_access, null: false, default: {}
      t.string :fallback

      t.timestamps
    end

    add_embargo_indexes
  end

  def add_embargo_indexes
    add_index :recording_studio_embargo_embargoes, :lifts_at
    add_index :recording_studio_recordings,
              :parent_recording_id,
              unique: true,
              name: CHILD_INDEX,
              where: child_index_where
  end

  def child_index_where
    if column_exists?(:recording_studio_recordings, :trashed_at)
      "recordable_type = '#{RECORDABLE_TYPE}' AND trashed_at IS NULL"
    else
      "recordable_type = '#{RECORDABLE_TYPE}'"
    end
  end
end
