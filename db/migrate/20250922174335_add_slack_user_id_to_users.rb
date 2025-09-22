class AddSlackUserIdToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :slack_user_id, :string
  end
end
