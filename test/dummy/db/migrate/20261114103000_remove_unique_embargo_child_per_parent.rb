# frozen_string_literal: true

class RemoveUniqueEmbargoChildPerParent < ActiveRecord::Migration[8.1]
  INDEX_NAME = "index_rs_embargo_child_per_parent"

  def up
    remove_index :recording_studio_recordings, name: INDEX_NAME, if_exists: true
  end

  def down
    # Not restored. A predicate captured at migrate time goes stale when
    # recording filters change, and 1=1 would let a trashed embargo block a new one.
  end
end
