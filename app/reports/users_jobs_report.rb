# frozen_string_literal: true

class UsersJobsReport < BaseReport
  attr_accessor :user_id

  params %i[start_date end_date department_id user xlsx_format]

  def call
    users = User
    users = users.where(department_id: department_ids) unless department_ids.blank?
    users = users.where(id: user_id) unless user_id.blank?
    users = users.all.to_a
    result[:users] = users.map do |user|
      item = {
        user_name: user.full_name,
        dates: {},
        counts: { fast: 0, long: 0, free: 0, mac_service: 0, total: 0 }
      }
      settings = {
        fast: :quick_orders,
        long: :service_jobs,
        free: :service_free_jobs
      }
      settings.each do |type, relation|
        jobs = user.send(relation).where(created_at: period).order(created_at: :asc)
        # jobs = jobs.preload(items: :features) if relation == :service_jobs
        jobs.each do |job|
          add_job(item, job, type)
        end
      end
      
      # Add mac service tasks for this user
      mac_tasks = DeviceTask.includes(:task)
                    .where(done_at: period, performer_id: user.id, task: Task.mac_service)
                    .in_department(department_ids.present? ? department_ids : [Department.current.id])
      mac_tasks.each do |device_task|
        add_mac_service_job(item, device_task)
      end
      
      item[:dates] = item[:dates].sort.to_h
      item[:dates].each do |date, jobs|
        item[:counts][:fast] += jobs[:fast].size
        item[:counts][:long] += jobs[:long].size
        item[:counts][:free] += jobs[:free].size
        item[:counts][:mac_service] += jobs[:mac_service].size
      end
      item[:counts][:total] = item[:counts].values.sum
      item[:counts][:total].zero? ? nil : item
    end.compact

    result
  end

  def add_job(item, job, type)
    date = job.created_at.strftime('%d.%m.%Y')
    time = job.created_at.strftime('%H:%M')
    item[:dates][date] ||= { fast: [], long: [], free: [], mac_service: [] }
    item[:dates][date][type] << { time: time, item: job }
  end

  def add_mac_service_job(item, device_task)
    date = device_task.done_at.strftime('%d.%m.%Y')
    time = device_task.done_at.strftime('%H:%M')
    item[:dates][date] ||= { fast: [], long: [], free: [], mac_service: [] }
    item[:dates][date][:mac_service] << { time: time, item: device_task }
  end

  def to_xlsx(workbook)
    workbook.add_worksheet(name: 'Report') do |sheet|
      header_style = sheet.styles.add_style(
        bg_color: 'E6E6E6',
        b: true,
        alignment: { horizontal: :center, vertical: :center },
        border: { style: :thin, color: '000000' }
      )
      detail_style = sheet.styles.add_style(
        bg_color: 'F5F5F5',
        border: { style: :thin, color: '000000' }
      )
      sheet.add_row ['', 'Быстрые', 'Длинные', 'Бесплатный сервис', 'Обновление или восстановление MacOS устройств'], style: header_style

      result[:users].each do |user|
        sheet.add_row [
          user[:user_name],
          user[:counts][:fast],
          user[:counts][:long],
          user[:counts][:free],
          user[:counts][:mac_service]
        ], style: detail_style

        user[:dates].each do |date, jobs|
          sheet.add_row [
            date,
            jobs[:fast].size,
            jobs[:long].size,
            jobs[:free].size,
            jobs[:mac_service].size
          ]
          sheet.add_row [
            '',
            jobs[:fast].map do |job|
              quick_order = job[:item]
              "#{job[:time]} #{quick_order.client_name || quick_order.contact_phone}"
            end.join(";\r\n "),
            jobs[:long].map do |job|
              service_job = job[:item]
              "#{job[:time]} #{service_job.presentation} #{service_job.client.presentation}"
            end.join(";\r\n "),
            jobs[:free].map do |job|
              service_free_job = job[:item]
              "#{job[:time]} #{service_free_job.client.presentation}"
            end.join(";\r\n "),
            jobs[:mac_service].map do |job|
              device_task = job[:item]
              "#{job[:time]} #{device_task.service_job.presentation} #{device_task.service_job.client.presentation}"
            end.join(";\r\n ")
          ]
        end
      end
      sheet.column_widths nil, nil, 100, 50
    end
  end
end
