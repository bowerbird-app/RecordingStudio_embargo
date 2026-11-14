# frozen_string_literal: true

class CreateRecordingStudioEmbargoEmbargoes < ActiveRecord::Migration[8.1]
  RECORDABLE_TYPE = "RecordingStudioEmbargo::Embargo"
  CHILD_INDEX = "index_rs_embargo_child_per_parent"

  def change
    create_table :recording_studio_embargo_embargoes, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.boolean :enabled, null: false, default: false
      t.datetime :lifts_at
      t.string :time_zone, null: false, default: "UTC"
      t.boolean :early_access, null: false, default: false

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
    "recordable_type = '#{RECORDABLE_TYPE}' AND #{RecordingStudio.kept_sql('recording_studio_recordings')}"
  end
end
