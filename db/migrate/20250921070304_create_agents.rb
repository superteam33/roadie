class CreateAgents < ActiveRecord::Migration[8.0]
  def change
    create_table :agents do |t|
      t.string :name
      t.string :agent_type
      t.string :status
      t.text :capabilities

      t.timestamps
    end
  end
end
