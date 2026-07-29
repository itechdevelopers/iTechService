class AddExcludedFromReportsToServiceJobs < ActiveRecord::Migration[5.1]
  def change
    add_column :service_jobs, :excluded_from_reports, :boolean, default: false, null: false
    # Партиальный индекс: сноска отчётов ищет редкие excluded=true записи.
    add_index :service_jobs, :excluded_from_reports,
              where: 'excluded_from_reports', name: 'index_service_jobs_excluded_from_reports'
  end
end
