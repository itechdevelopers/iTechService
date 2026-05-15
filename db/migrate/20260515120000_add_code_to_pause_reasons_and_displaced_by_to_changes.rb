class AddCodeToPauseReasonsAndDisplacedByToChanges < ActiveRecord::Migration[5.1]
  def change
    add_column :repair_pause_reasons, :code, :string
    add_index  :repair_pause_reasons, :code, unique: true

    add_reference :repair_status_changes, :displaced_by_service_job,
                  foreign_key: { to_table: :service_jobs }, index: true
  end
end
