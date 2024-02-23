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

  def time_to_return_ru(service_job, time_string_ru = [])
    date_times = date_times(service_job)
    return unless date_times

    return t 'dashboard.time_up' if date_times[:current] > date_times[:return_at] # время вышло

    seconds = ((date_times[:return_at] - date_times[:current]) * 24 * 60 * 60).to_i # получаем разницу в секундах

    # Пример: 1 mo 14 days 23 hrs 58 mins 23 secs
    # Если format: :short - 1mo 14d 23h 58m 23s
    time_string_en = ChronicDuration.output(seconds, format: :short)

    data_array = time_string_en.split(' ')

    return unless data_array.present?

    data_array.each do |item|
      case
      when item.include?('mo') then time_string_ru << [item.to_i, Russian.p(item.to_i, "месяц", "месяца", "месяцев")].join(' ')
      when item.include?('d')  then time_string_ru << [item.to_i, Russian.p(item.to_i, "день", "дня", "дней")].join(' ')
      when item.include?('h')  then time_string_ru << [item.to_i, Russian.p(item.to_i, "час", "часа", "часов")].join(' ')
      when item.include?('m')  then time_string_ru << [item.to_i, Russian.p(item.to_i, "минута", "минуты", "минут")].join(' ')
      when item.include?('s')  then time_string_ru << [item.to_i, Russian.p(item.to_i, "секунда", "секунды", "секунд")].join(' ')
      end
    end

    time_string_ru.join(' ')
  end

  def table_highlighting(service_job)
    seconds = diff_seconds service_job
    return unless seconds

    return 'time-out' if seconds.negative?

    case seconds
    when 3601..10800 then 'warning'
    when 0..3600 then 'danger'
    else 'info'
    end
  end

  def diff_seconds(service_job)
    date_times = date_times(service_job)
    return unless date_times

    ((date_times[:return_at] - date_times[:current]) * 24 * 60 * 60).to_i # получаем разницу в секундах
  end

  def date_times(service_job)
    return unless service_job.return_at

    {current: DateTime.current, return_at: DateTime.parse(service_job.return_at.to_s)}
  end

  def edited_by_tag(note)
    last_edit = RecordEdit.find_by(editable: note)
    label = ""
    if last_edit.present?
      label = "Отредактировано #{last_edit.user.short_name} [#{l(last_edit.updated_at, format: :date_time)}]"
    end
    content_tag :i, label
  end

  def note_history_tag(note)
    link_to(glyph(:time),
            record_edits_path(editable_type: note.class.to_s, editable_id: note.id.to_s),
            remote: true) if RecordEdit.any_edits?(note)
  end

  def ready_for_payment?(service_job)
    (service_job.work_order_filled? && service_job.completion_act_printed_at.present?) || !service_job.work_order_filled?
  end

  def photo_gallery_mini(service_job, division)
    container = service_job.photo_container
    default_res = content_tag(:span, "Нет фотографий", class: "no-photos")
    return default_res unless container.present?

    content_tag(:div, class: "photo-gallery-mini", data: { division: division }) do
      div_html = ""
      if container.send("#{division}_photos").present?
        div_html += content_tag(:div, "", class: "btn-gallery-left", data: { division: division })
        container.send("#{division}_photos").each_with_index do |photo, index|
          one = index == 0 ? true : false
          two = index == 1 ? true : false
          div_html += content_tag(:div, class: "mini-photo #{'mini-chosen-one' if one} #{'mini-chosen-two' if two}", data: { division: division }) do
            res = ""
            res += link_to image_tag(photo.thumb.url), service_job_photo_path(service_job, index, division: division), data: { remote: true }, title: "#{index + 1}/#{container.send("#{division}_photos").count}"
            res += link_to service_job_photo_path(service_job, index, division: division), method: :delete, data: { confirm: 'Вы уверены?' }, class: "delete-photo" do "#{glyph(:trash)}".html_safe; end
            res.html_safe
          end
        end
        div_html += content_tag(:div, "", class: "btn-gallery-right", data: { division: division })
        div_html.html_safe
      else
        default_res
      end
    end
  end

  def photo_gallery(photos, chosen_photo_id, data)
    gallery_html = []
    gallery_html << content_tag(:div, "", class: "btn-gallery-left")
    gallery_html << content_tag(:div, class: "gallery") do
      div_html = ""
      photos.each_with_index do |photo, index|
        div_html += content_tag(:div, class: "photo #{'chosen' if index == chosen_photo_id}") do
        content_tag(:span, class: "photo-index") do
          user_name = JSON.parse(data[index].gsub(/:([a-zA-z]+)/,'"\\1"').gsub('=>', ': '))["user"]
          date = JSON.parse(data[index].gsub(/:([a-zA-z]+)/,'"\\1"').gsub('=>', ': '))["date"]
          "Добавлено #{user_name}<br>#{date}".html_safe
        end +
        content_tag(:img, "", src: photo.url).html_safe
        end
      end
      div_html.html_safe
    end
    gallery_html << content_tag(:div, "", class: "btn-gallery-right")
    gallery_html.join.html_safe
  end
end
