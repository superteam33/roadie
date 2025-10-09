class CreateGithubProjectMappings < ActiveRecord::Migration[8.0]
  def change
    create_table :github_project_mappings do |t|
      t.bigint :project_id, null: false
      t.string :github_project_id
      t.integer :github_project_number, null: false
      t.string :github_repo_name, null: false
      t.string :github_org_name, null: false

      t.timestamps
    end
    
    add_index :github_project_mappings, :project_id, unique: true
    add_index :github_project_mappings, :github_project_id, unique: true
    add_foreign_key :github_project_mappings, :projects
  end
end
