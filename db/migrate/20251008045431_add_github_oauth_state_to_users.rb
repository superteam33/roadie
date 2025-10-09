class AddGithubOauthStateToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :github_oauth_state, :string
  end
end
