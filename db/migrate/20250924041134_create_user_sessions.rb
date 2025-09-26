class CreateUserSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :user_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :access_token, null: false
      t.datetime :expires_at, null: false
      t.boolean :is_active, default: true, null: false

      t.timestamps
    end
    
    add_index :user_sessions, :access_token, unique: true
    add_index :user_sessions, [:user_id, :is_active]
    add_index :user_sessions, :expires_at
  end
end
