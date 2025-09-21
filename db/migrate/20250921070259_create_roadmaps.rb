class CreateRoadmaps < ActiveRecord::Migration[8.0]
  def change
    create_table :roadmaps do |t|
      t.string :title
      t.text :description
      t.references :project, null: false, foreign_key: true

      t.timestamps
    end
  end
end
