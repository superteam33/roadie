class AddGithubFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :github_access_token, :text
    add_column :users, :github_username, :string
    
    add_index :users, :github_username, unique: true
  end
end
