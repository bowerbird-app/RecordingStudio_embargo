# frozen_string_literal: true

class CreateRecordingStudioEmbargoEmbargoes < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_embargo_embargoes, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.boolean :enabled, null: false, default: false
      t.datetime :lifts_at
      t.string :time_zone, null: false, default: "UTC"
      t.boolean :early_access, null: false, default: false

      t.timestamps
    end

    add_index :recording_studio_embargo_embargoes, :lifts_at
  end
end
