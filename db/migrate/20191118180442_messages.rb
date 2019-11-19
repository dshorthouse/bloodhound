class Messages < ActiveRecord::Migration[6.0]
  def up
    create_table :messages, if_not_exists: true do |t|
      t.integer :user_id, null: false
      t.integer :recipient_id, null: false
      t.bigint :occurrence_id
      t.text :message
      t.boolean :read, default: false
      t.timestamp :created_at, default: -> { 'CURRENT_TIMESTAMP' }
      t.timestamp :updated_at
      t.index :user_id
      t.index :recipient_id
      t.index :occurrence_id
    end
  end

  def down
    drop_table(:messages, if_exists: true)
  end
end
