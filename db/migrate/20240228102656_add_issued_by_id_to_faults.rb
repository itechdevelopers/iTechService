class AddIssuedByIdToFaults < ActiveRecord::Migration[5.1]
  def change
    add_reference :faults, :issued_by, foreign_key: { to_table: :users, optional: true }
  end
end
