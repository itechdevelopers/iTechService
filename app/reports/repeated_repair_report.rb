# frozen_string_literal: true

class RepeatedRepairReport < BaseReport
  def call
    jobs = ServiceJob.select('item_id, serial_number, imei, count(*) qty')
                     .group('item_id, serial_number, imei').having('count(*) > 1')
    jobs = jobs.in_department(department) if department
    jobs = jobs.where(created_at: period)
    result[:jobs] = jobs
    result[:jobs_size] = jobs.to_a.size

    item_to_jobs = {}
    jobs.each do |job|
      service_jobs = ServiceJob.where(created_at: period, item_id: job.item_id).in_department(department)
      jobs_and_tasks = service_jobs.map do |sj|
        {
          service_job: sj,
          tasks: sj.device_tasks.map(&:task_name)
        }
      end
      item_to_jobs[job.item_id] = jobs_and_tasks
    end
    result[:item_to_jobs] = item_to_jobs
    result[:sj_to_tasks] = process_service_jobs(item_to_jobs)
    result
  end

  def process_service_jobs(input_hash)
    result = {}

    input_hash.each do |item_id, service_jobs|
      task_counts = Hash.new(0)

      service_jobs.each do |job|
        job[:tasks].each do |task|
          task_counts[task] += 1
        end
      end

      result[item_id] = task_counts.map { |task, count| "#{task} > #{count}" }.join(", ")
    end

    result
  end
end
