class AddServiceJobSortingIdToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :service_job_sorting_id, :integer
  end
end
