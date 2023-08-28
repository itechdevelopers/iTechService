class CreateServiceJobSortings < ActiveRecord::Migration[5.1]
  def change
    create_table :service_job_sortings do |t|
      t.string :title
      t.string :direction
      t.string :column
      t.integer :user_id
    end
  end
end
