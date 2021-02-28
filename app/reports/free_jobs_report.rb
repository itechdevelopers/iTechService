class FreeJobsReport < BaseReport
  SUBJECTS = %i[performer receiver]

  attr_accessor :subject

  params [:start_date, :end_date, :department_id, :subject]

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
end
