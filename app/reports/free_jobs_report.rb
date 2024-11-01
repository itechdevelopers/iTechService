class FreeJobsReport < BaseReport
  SUBJECTS = %i[performer receiver]

  attr_accessor :subject

  params [:start_date, :end_date, :department_id, :subject, :xlsx_format]

  def call
    result[:users] = []
    free_jobs = Service::FreeJob.joins(subject.to_sym, :task)
                    .in_department(department).where(performed_at: period)
    users_free_jobs = free_jobs.order('count_id desc').group("#{subject}_id").count(:id).map do |user_id, free_jobs_qty|
      user_name = User.select(:name, :surname).find_by(id: user_id)&.short_name
      user_free_jobs = free_jobs.where("#{subject}_id" => user_id)

      free_tasks = user_free_jobs.order('count_id desc').group(:task_id).count(:id).transform_keys do |task_id|
        free_task = Service::FreeTask.find_by(id: task_id)
        free_task.name
      end

      { name: user_name, qty: free_jobs_qty, free_tasks: free_tasks }
    end
    result[:users] = users_free_jobs
    result[:total] = free_jobs.count
    result
  end

  def subjects_collection
    SUBJECTS.map { |subject| [I18n.t("reports.free_jobs.subject/#{subject}"), subject] }
  end

  def to_xlsx(workbook)
    workbook.add_worksheet(name: 'Tasks Report') do |sheet|
      header_style = sheet.styles.add_style(
        bg_color: 'E6E6E6',
        b: true,
        alignment: { horizontal: :center, vertical: :center },
        border: { style: :thin, color: '000000' }
      )

      main_row_style = sheet.styles.add_style(
        border: { style: :thin, color: '000000' },
        b: true
      )

      detail_row_style = sheet.styles.add_style(
        border: { style: :thin, color: '000000' },
        bg_color: 'F5F5F5'
      )

      total_row_style = sheet.styles.add_style(
        border: { style: :thin, color: '000000' },
        b: true,
        bg_color: 'E6E6E6'
      )

      sheet.add_row [
        Service::FreeJob.human_attribute_name(subject),
        I18n.t('reports.qty')
      ], style: header_style

      result[:users].each do |user|
        sheet.add_row [
          user[:name],
          user[:qty]
        ], style: main_row_style

        user[:free_tasks].each do |task_name, qty|
          sheet.add_row [
            task_name,
            qty
          ], style: detail_row_style
        end
      end

      sheet.add_row [
        I18n.t('reports.total'),
        result[:total]
      ], style: total_row_style

      sheet.column_widths 40, 15
    end
  end
end
