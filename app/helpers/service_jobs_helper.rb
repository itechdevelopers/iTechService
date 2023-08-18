# encoding: utf-8
module ServiceJobsHelper
  TG_URL = 'https://t.me/'

  def service_job_status_options(selected = nil)
    options_for_select [
                         [t('service_jobs.status.all'), nil],
                         [t('service_jobs.status.done'), 'done'],
                         [t('service_jobs.status.pending'), 'pending'],
                         [t('service_jobs.status.important'), 'important'],
                       ],
                       selected
  end

  def row_class_for_task(task)
    if task.present?
      task.done? ? 'success' : task.pending? ? (task.is_important? ? 'error' : 'warning') : ''
    else
      ''
    end
  end

  def row_class_for_service_job(service_job)
    if service_job.at_done?
      'success'
    elsif service_job.in_archive?
      'info'
    end
  end

  def progress_badge_class_for_service_job(service_job)
    badge_class = 'badge badge-'
    badge_class << (service_job.processed_tasks.count == 0 ? 'important' : (service_job.pending? ? 'warning' : 'success'))
  end

  def device_moved_by(service_job)
    (user = service_job.moved_by).present? ? user.username : '-'
  end

  def device_moved_at(service_job)
    (time = service_job.moved_at).present? ? human_datetime(time) : '-'
  end

  def task_list_for(service_job)
    content_tag(:ul, style: 'list-style:none; text-align:left; margin:0') do
      service_job.device_tasks.collect do |task|
        content_tag(:li, "#{icon_tag(task.done ? 'check' : 'check-empty')} #{task.task_name}")
      end.join.html_safe
    end.html_safe
  end

  def device_movement_history(service_job)
    history = service_job.movement_history
    content_tag(:table, class: 'movement_history ') do
      history.map do |h|
        time = h[0].present? ? l(h[0], format: :date_time) : '-'
        location = h[1].present? ? Location.find(h[1]).try(:name) || '-' : '-'
        user = h[2].present? ? User.find(h[2]).try(:full_name) || '-' : '-'
        content_tag(:tr) do
          content_tag(:td, time) + content_tag(:td, location) + content_tag(:td, user)
        end
      end.join.html_safe
    end.html_safe
  end

  def device_movement_telegram_tag(work_phone)
    telegram_link_to(TG_URL + work_phone.to_s)
  end

  def device_movement_information_tag(service_job)
    user, time = service_job.moved_by, service_job.moved_at
    text = (user.present? and time.present?) ? t('moved', user: user.full_name, time:
        distance_of_time_in_words_to_now(time)) : '-'
    history_link_to(movement_history_service_job_path(service_job)) + content_tag(:span, text)
  end

  def itunes_string_for(service_job)
    "#{service_job.created_at.strftime('%d.%m.%y')}  #{service_job.ticket_number}  #{service_job.client.name}"
  end

  def returning_devices_list(service_jobs)
    if service_jobs.any?
      now = DateTime.current.change(sec: 0)
      content_tag(:table, id: 'returning_devices_list', class: 'table table-condensed table-hover') do
        service_jobs.map do |service_job|
          content_tag(:tr) do
            time_text = "#{t('in_time') if service_job.return_at.future?} #{distance_of_time_in_words(now, service_job.return_at)} #{t('ago') if service_job.return_at.past?}"
            content_tag(:td, time_text) +
            content_tag(:td, link_to(service_job.presentation, service_job_path(service_job), target: '_blank')) +
            content_tag(:td, link_to(glyph(:phone), '#', class: 'returning_device_tooltip', data: {html: true, placement: 'top', trigger: 'manual', title: content_tag(:span, service_job.client_full_name) + tag(:br) + content_tag(:strong, human_phone(service_job.contact_phone))}))
          end
        end.join.html_safe
      end.html_safe
    else
      ''
    end
  end

  def header_link_for_device_returning
    service_jobs = ServiceJob.for_returning
    notify_class = service_jobs.any? ? 'notify' : ''
    content_tag(:li, id: 'device_returning', class: notify_class) do
      link_to glyph('mobile-phone'), '#', rel: 'popover', id: 'device_returning_link', data: { html: true, placement: 'bottom', title: t('service_jobs.returning_popover_title'), content: returning_devices_list(service_jobs).gsub('\n', '') }
    end
  end

  def contact_phones_for(service_job)
    if service_job.client.present?
      phones = []
      phones << human_phone(service_job.client.contact_phone) unless service_job.client.contact_phone.blank?
      phones << human_phone(service_job.client.full_phone_number) unless service_job.client.full_phone_number.blank?
      phones << human_phone(service_job.client.phone_number) unless service_job.client.phone_number.blank?
      phones.join ', '
    end
  end

  def sales_info(service_job)
    content = []
    if (number = service_job.serial_number.present? ? service_job.serial_number : service_job.imei).present?
      if (item = Item.search(q: number, saleinfo: true).first).present?
        content << content_tag(:span, item.sale_info[:sale_info], class: 'sales_info')
      end
      if (imported_sales = ImportedSale.search(search: number)).any?
        content << content_tag(:span, imported_sales.map { |sale| "[#{sale.sold_at.strftime('%d.%m.%y')}: #{sale.quantity}]" }.join(' '), class: 'imported_sales_info')
      end
      content.present? ? content.join(' ').html_safe : '-'
    else
      '?'
    end
  end

  def button_to_archive_service_job(service_job, hidden: false)
    link_to "#{glyph(:archive)} #{t('service_jobs.move_to_archive')}".html_safe,
            archive_service_job_path(service_job), method: :put, remote: true,
            id: 'service_job_archive_button', class: "btn btn-warning#{' hidden' if hidden}"
  end

  def service_tasks_list(service_job)
    content_tag(:ul, id: 'device_tasks_list') do
      service_job.device_tasks.collect do |device_task|
        content_tag :li do
          content_tag(:div, device_task.name) +
          content_tag(:div, device_task.comment, class: 'text-info') +
          content_tag(:div, device_task.user_comment, class: 'text-error') +
          content_tag(:div, "#{distance_of_time_in_words_to_now(device_task.created_at)} #{t(:ago)}", class: 'muted')
        end
      end.join.html_safe
    end
  end

  def button_to_set_keeper_of_device(service_job)
    button_class = 'service_job-keeper-button btn btn-small'
    hint = "#{ServiceJob.human_attribute_name(:keeper)}: "
    if service_job.keeper.present?
      button_class += ' btn-info'
      hint += service_job.keeper.short_name
    else
      button_class += ' btn-default'
      hint += '-'
    end
    form_for [:set_keeper, service_job], remote: true, html: {class: 'button_to service_job-keeper-form'} do |f|
      # hidden_field_tag('service_job[keeper_id]', current_user.id) +
      button_tag(glyph('user'), class: button_class, title: hint)
    end
  end

  def service_job_template_field_data(field_name, templates)
    field_templates = templates[field_name]
    return {} unless field_templates.present?

    list_items = field_templates.map do |field_template|
      content_tag(:li, field_template.content, class: 'service-job_template')
    end.join

    templates_list = content_tag(:ul, list_items, class: 'service-job_templates-list')

    {
      html: true,
      placement: 'right',
      trigger: 'manual',
      title: t('service_jobs.form.templates'),
      content: templates_list.gsub('"', '').html_safe
    }
  end

  def new_sms_notification_link(service_job)
    link_to t('service_jobs.send_sms'), new_service_sms_notification_path(service_job_id: service_job.id), remote: true,
            id: 'new_sms_notification_link', class: 'btn'
  end

  def time_to_return_ru(service_job, result = [])
    current_datetime = DateTime.current
    return_at_datetime = DateTime.parse(service_job.return_at.to_s)

    return t 'dashboard.time_up' if current_datetime > return_at_datetime # время вышло

    secs = ((return_at_datetime - current_datetime) * 24 * 60 * 60).to_i # получаем разницу в секундах
    str = ChronicDuration.output(secs) #

    data_array = str.split(' ').map { |x| x[/\d+/] }.compact

    return unless data_array.present?

    data_array.reverse.each.with_index(1) do |data, index|
      case index
      when 1 then result << [data.to_i, Russian.p(data.to_i, "секунда", "секунды", "секунд")].join(' ')
      when 2 then result << [data.to_i, Russian.p(data.to_i, "минута", "минуты", "минут")].join(' ')
      when 3 then result << [data.to_i, Russian.p(data.to_i, "час", "часа", "часов")].join(' ')
      when 4 then result << [data.to_i, Russian.p(data.to_i, "день", "дня", "дней")].join(' ')
      when 5 then result << [data.to_i, Russian.p(data.to_i, "месяц", "месяца", "месяцев")].join(' ')
      when 5 then result << [data.to_i, Russian.p(data.to_i, "месяц", "месяца", "месяцев")].join(' ')
      end
    end

    result.reverse.join(' ')
  end
end
