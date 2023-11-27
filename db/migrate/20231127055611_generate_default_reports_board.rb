class GenerateDefaultReportsBoard < ActiveRecord::Migration[5.1]
  def up
    # Creates also a default column
    rb = ReportsBoard.create(name: "Default")
    rcol = rb.report_columns.first
    pos = 0
    %w[device_groups users devices_archived devices_not_archived active_tasks done_tasks done_tasks_copy
      clients tasks_duration device_orders orders_statuses devices_movements payments salary driver few_remnants_goods
      few_remnants_spare_parts body_repair_jobs repair_jobs technicians_jobs technicians_difficult_jobs repairers remnants
      sales margin quick_orders free_jobs phone_substitutions sms_notifications service_jobs_at_done repair_parts
      defected_spare_parts service_job_viewings contractors_defected_spare_parts uniform repeated_repair repeated_repair2
      users_jobs mac_service warranty_repair_parts].each do |r_name|
        ReportCard.create(content: r_name, report_column_id: rcol.id, position: pos)
        pos += 1
      end
  end

  def down
    ReportCard.destroy_all
    ReportColumn.destroy_all
    ReportsBoard.destroy_all
  end
end
