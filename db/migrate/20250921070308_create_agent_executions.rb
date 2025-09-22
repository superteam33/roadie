class CreateAgentExecutions < ActiveRecord::Migration[8.0]
  def change
    create_table :agent_executions do |t|
      t.references :agent, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: { to_table: :users }
      t.string :status
      t.text :input
      t.text :output
      t.integer :execution_time

      t.timestamps
    end
  end
end
