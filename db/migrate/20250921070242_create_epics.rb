class CreateEpics < ActiveRecord::Migration[8.0]
  def change
    create_table :epics do |t|
      t.string :name
      t.text :description
      t.string :status
      t.string :priority
      t.references :project, null: false, foreign_key: true

      t.timestamps
    end
  end
end
