class CreateTestingSessions < ActiveRecord::Migration[5.1]
  def change
    create_table :testing_sessions do |t|
      t.references :service_job, null: false, foreign_key: true, index: true
      t.references :sender,          foreign_key: { to_table: :users },     index: true
      t.references :target_location, foreign_key: { to_table: :locations },  index: true
      t.references :tester,          foreign_key: { to_table: :users },     index: true
      t.text     :what_to_test
      t.string   :status, null: false, default: 'not_started', index: true
      t.datetime :started_at
      t.datetime :ended_at
      t.text     :notes
      t.string   :failure_action
      t.timestamps
    end
  end
end
