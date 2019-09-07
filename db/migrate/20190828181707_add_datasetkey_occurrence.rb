class AddDatasetkeyOccurrence < ActiveRecord::Migration[6.0]
  def up
    add_column :occurrences, :datasetKey, :string, after: :gbifID, limit: 50
    add_index :occurrences, :datasetKey
  end
  
  def down
    remove_column :occurrences, :datasetKey, :string, after: :gbifID, limit: 50
    remove_index :occurrences, :datasetKey
  end
end
