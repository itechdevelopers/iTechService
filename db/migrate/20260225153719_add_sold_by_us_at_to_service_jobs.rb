class AddSoldByUsAtToServiceJobs < ActiveRecord::Migration[5.1]
  def change
    add_column :service_jobs, :sold_by_us_at, :date
  end
end
