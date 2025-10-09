class CreateGithubTaskMappings < ActiveRecord::Migration[8.0]
  def change
    create_table :github_task_mappings do |t|
      t.bigint :task_id, null: false
      t.string :github_issue_id, null: false
      t.string :github_project_item_id
      t.integer :github_issue_number, null: false

      t.timestamps
    end
    
    add_index :github_task_mappings, :task_id, unique: true
    add_index :github_task_mappings, :github_issue_id, unique: true
    add_index :github_task_mappings, :github_issue_number
    add_foreign_key :github_task_mappings, :tasks
  end
end
