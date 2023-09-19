class AddReturnAtIndexToServiceJobs < ActiveRecord::Migration[5.1]
  def change
    add_index :service_jobs, :return_at
  end
end
