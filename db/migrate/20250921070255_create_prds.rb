class CreatePrds < ActiveRecord::Migration[8.0]
  def change
    create_table :prds do |t|
      t.string :title
      t.text :content
      t.string :status
      t.references :project, null: false, foreign_key: true

      t.timestamps
    end
  end
end
