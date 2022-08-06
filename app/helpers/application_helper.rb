module ApplicationHelper
  def logo_tag
    image_tag "/uploads/#{Setting.app_logo_filename}"
  end

  def link_to_add_fields(name, append_to_selector, f, association, options = {})
    new_object = f.object.class.reflect_on_association(association).klass.new
    fields = f.fields_for(association, new_object, child_index: "new_#{association}") do |builder|
      partial = options.delete(:partial) || "#{association.to_s.singularize}_fields"
      render(partial, f: builder, index: "new_#{association}", options: options)
    end
    link_to '#', class: 'add_fields btn-mini btn-success btn',
            data: {selector: append_to_selector, association: association, content: (fields.gsub('\n', ''))} do
      glyph(:plus) + ' ' + name
    end
  end

  def link_to_remove_fields(f)
    content_tag :span do
      f.hidden_field(:_destroy) +
        link_to('#', class: 'remove_fields btn btn-mini btn-danger') { tag('i', class: 'icon-minus') }
    end
  end

  def sortable(column, title = nil, remote: false)
    column = column.to_s
    title ||= column.titleize

    if column == sort_column
      css_class = "current #{sort_direction} nav nav-pills"
      direction = sort_direction == 'asc' ? 'desc' : 'asc'
      icon_name = (sort_direction == 'asc') ? 'caret-up' : 'caret-down'
    else
      css_class = 'nav nav-pills'
      icon_name = 'sort'
      direction = 'asc'
    end
    title = "#{title} #{icon_tag(icon_name)}".html_safe
    attr = params.to_unsafe_h.deep_symbolize_keys
    link_to title, attr.merge(sort: column, direction: direction, page: nil), {class: css_class, remote: remote}
  end

  def sort_fields
    hidden_field_tag(:direction, params[:direction]) +
      hidden_field_tag(:sort, params[:sort])
  end

  def search_button
    button_tag type: 'submit', class: 'btn btn-info' do
      icon_tag(:search) + t(:search)
    end
  end

  def timestamp_string_for(object)
    "[#{object.class.human_attribute_name(:created_at)}: #{l(object.created_at, format: :date_time)} | " +
      "#{object.class.human_attribute_name(:updated_at)}: #{l(object.updated_at, format: :date_time)}]"
  end

  def nav_state_for(controller)
    controller_name == controller ? 'active' : ''
  end

  def link_to_new(object_class, name = nil, options = {})
    options.merge! class: 'btn btn-success btn-large'
    name ||= t("#{object_class.model_name.collection}.new.title", default: t('new'))
    link_to url_for(controller: object_class.model_name.route_key, action: 'new'), options do
      "#{glyph(:plus)} #{name}".html_safe
    end
  end

  def link_to_show(object, options = {})
    options.merge! class: 'btn'
    name = t 'show'
    link_to url_for(controller: object.model_name.route_key, action: 'show', id: object.id), options do
      "#{glyph(:eye)} #{name}".html_safe
    end
  end

  def link_to_edit(object, options = {})
    options.merge! class: 'btn'
    name = t 'edit'
    link_to url_for(controller: object.model_name.route_key, action: 'edit', id: object.id), options do
      "#{glyph(:edit)} #{name}".html_safe
    end
  end

  def link_to_destroy(object, options = {})
    options.merge! class: 'btn btn-danger', method: 'delete',
                   data: {confirm: t('confirmation', default: 'Are you sure?')}
    name = t 'destroy'
    link_to url_for(controller: object.model_name.route_key, action: 'destroy', id: object.id), options do
      "#{glyph(:trash)} #{name}".html_safe
    end
  end

  def submit_button(form, options = {})
    options.merge! class: 'submit_button btn btn-primary ' + (options[:class] || ''), type: 'submit'
    model_name = form.object.class.model_name
    human_model_name = model_name.human
    action = form.object.persisted? ? 'update' : 'create'
    if options[:name] == false
      name = nil
    else
      name = options[:name] || t("helpers.button.#{model_name}.#{action}", model: human_model_name, default: t(action, default: 'Save'))
    end
    button_tag options do
      "#{glyph(:save)} #{name}".html_safe
    end
  end

  def link_to_show_small(object, options = {})
    options.merge! class: 'btn btn-small'
    link_to icon_tag('eye-open'), url_for(controller: object.class.name.tableize, action: 'show', id: object.id), options
  end

  def link_to_edit_small(object, options = {})
    options.merge! class: 'btn btn-small'
    link_to icon_tag(:edit), url_for(controller: object.class.name.tableize, action: 'edit', id: object.id), options
  end

  def link_to_destroy_small(object, options = {})
    options.merge! class: 'btn btn-small btn-danger', method: 'delete',
                   data: {confirm: t('helpers.links.confirm', default: 'Are you sure?')}
    link_to icon_tag(:trash), url_for(controller: object.class.name.tableize, action: 'destroy', id: object.id), options
  end

  def human_history_value(rec)
    if rec.new_value.present?
      case rec.column_type
      when 'boolean'
        icon_class = rec.new_value == 't' ? 'check' : 'check-empty'
        val = icon_tag icon_class
      when 'integer'
        case rec.column_name
        when 'client_id'
          val = Client.find(rec.new_value).try(:full_name)
        when 'location_id'
          val = Location.find(rec.new_value).try(:name)
        when 'service_jobs_id'
          val = ServiceJob.find(rec.new_value).try(:presentation)
        when 'task_id'
          val = Task.find(rec.new_value).try(:name)
        when 'nominal'
          val = rec.object.is_a?(GiftCertificate) ? human_gift_certificate_nominal(rec.object) : rec.new_value
        when 'status'
          val = rec.object.is_a?(GiftCertificate) ? rec.object.status_h : rec.new_value
        else
          val = rec.new_value
        end
      else
        val = rec.new_value
      end
    else
      val = '-'
    end
    val
  end

  def attribute_changed_by(object, attribute)
    object.history_records
  end

  def human_date(date)
    return '' unless date.present?

    l date.to_date, format: :default
  end

  def human_datetime(date)
    return '' unless date.present?

    l date.to_datetime, format: :date_time
  end

  def date_field(form, attr)
    content_tag(:div, class: 'input-append') do
      form.text_field(attr, class: 'span5') +
        link_to(glyph(:calendar), '#', class: 'btn datepicker')
    end
  end

  def icon_tag(name, type = nil)
    white_class = type.to_s == 'white' ? 'icon-white' : ''
    "<i class='icon-#{name.to_s} #{white_class}'></i>".html_safe
  end

  def title_for(model_class)
    case action_name
    when 'index'
      t '.title'
    when 'show'
      t '.title', default: model_class.model_name.human
    else
      t '.title', default: t("#{action_name.humanize} #{model_class.model_name.human}")
    end
  end

  def auto_title(object = nil)
    title = if object.present?
              view_key = object.persisted? ? 'edit' : 'new'
              t("#{object.model_name.route_key}.#{view_key}.title")
            else
              t('.title', default: controller_name.classify.constantize.model_name.human)
            end

    content_for(:title, title)
    title.html_safe
  end

  def auto_header_tag(object = nil, title = nil, button_name = nil)
    model_class = object.present? ? object.class : controller_name.classify.constantize
    title ||= (action_name == 'index') ? auto_title : auto_title(object)

    content_tag(:div, class: 'page-header') do
      if action_name == 'index'
        content = content_tag(:h1, title)
        content << link_to_new(model_class, button_name) if can?(:create, model_class)
        content
      else
        content_tag :h1, link_back_to_index + title
      end
    end
  end

  def caret_tag
    content_tag(:b, nil, class: 'caret').html_safe
  end

  def history_link_to(url)
    link_to glyph(:time), url, class: 'history_link', remote: true
  end

  def telegram_link_to(url)
    link_to(image_tag('/tg.png', width: '20'), url, class: 'telegram_link', target: '_blank')
  end

  def store_location
    session[:return_to] = request.fullpath.gsub(/.js/, '')
  end

  def clear_return_to
    session[:return_to] = nil
  end

  def redirect_back_or(default, options = {})
    redirect_to session[:return_to] || default, options
    clear_return_to
  end

  def button_to_close_popover(options = {})
    link_to "&times;".html_safe, '#', options.merge(class: 'close_popover_button')
  end

  def button_to_close_modal
    content_tag(:a, glyph('remove-sign'), class: 'close close_modal_button', 'data-dismiss' => 'modal', href: '#')
  end

  def modal_header_tag(title = nil)
    content_tag(:div, class: 'modal-header') do
      content_tag(:h3) do
        button_to_close_modal + title
      end
    end
  end

  def humanize_duration(val)
    h = (val / 60).round
    m = (val % 60).round
    h > 0 ? t('hour_min', hour: h, min: m) : t('min', min: m)
  end

  def human_percent(value)
    value.nil? ? '-' : number_to_percentage(value, precision: 0)
  end

  def human_currency(value, with_unit = false)
    value.nil? ? '-' : (with_unit ? number_to_currency(value, precision: 0, delimiter: ' ', separator: ',') : number_to_currency(value, precision: 2, delimiter: ' ', separator: ',', unit: ''))
  end

  def human_phone(value)
    value.nil? ? '-' : number_to_phone(value, area_code: true)
  end

  def human_number(value)
    number_to_human value, precision: 2, delimiter: ' ', separator: ','
  end

  def spinner_tag
    content_tag(:b, glyph('spinner'), id: 'spinner')
  end

  def header_link_to_scan_barcode
    link_to glyph(:barcode), '#', remote: true, id: 'scan_barcode_button'
  end

  def button_to_update(name, document, attributes)
    class_name = document.class.to_s.downcase
    parameters = {controller: class_name.tableize, action: 'update', id: document.id, method: :patch, data: {confirm: t('confirmation')}}
    parameters[class_name.to_sym] = attributes
    button_to name, parameters, {class: 'btn btn-primary'}
  end

  def header_link_to_change_user
    content_tag(:li, class: 'dropdown') do
      link_to(caret_tag, '#', class: 'dropdown-toggle', 'data-toggle' => 'dropdown') +
      content_tag(:ul, class: 'dropdown-menu') do
        User.for_changing.map do |user|
          content_tag(:li, link_to("#{user.username} [#{user.role}]", become_path(user)))
        end.join.html_safe
      end
    end
  end

  def duck_plan_tag
    if (value = Setting.duck_plan(current_user.department)).present? and (url = Setting.duck_plan_url(current_user.department)).present?
      link_to url, id: 'duck_plan_link' do
        concat t('plan_for')
        concat image_tag('duck_40.png')
        concat value
      end
    end
  end

  def buttons_for_tree
    content_tag(:div, id: 'tree_buttons', class: 'btn-toolbar') do
      content_tag(:div, class: 'btn-group') do
        content_tag(:button, '1', class: 'btn btn-mini') +
        content_tag(:button, '2', class: 'btn btn-mini') +
        content_tag(:button, '3', class: 'btn btn-mini')
      end
    end
  end

  def error_messages_for(record)
    record.errors.full_messages.join('. ') if record.errors.present?
  end

  def additional_params
    params.permit!.to_h.except(:controller, :action, :id, :format)
  end
end
