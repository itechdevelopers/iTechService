module ElectronicQueuesHelper
  def queue_items_trees_tag(queue_items, current_id = nil, options = {})
    queue_items.map do |queue_item|
      queue_items_tree_tag queue_item, current_id, options
    end.join.html_safe
  end

  def queue_items_tree_tag(queue_item, current_id = nil, options = {})
    content_tag :ul, nested_queue_items_list(queue_item.subtree.not_archived.arrange(order: :position), current_id, options),
                class: 'queue_items_tree unstyled', id: "queue_items_tree_#{queue_item.id}",
                data: { root_id: queue_item.id, queue_item_id: current_id, opened: [current_id] }
  end

  def nested_queue_items_list(queue_items, current_id = nil, options = {})
    queue_items.map do |queue_item, sub_queue_items|
      is_current = queue_item.id == current_id.to_i
      li_class = 'opened'
      li_class << ' current' if is_current
      nested_list = content_tag(:ul, nested_queue_items_list(sub_queue_items, current_id, options))
      options[:group] = queue_item.id

      content_tag :li, link_to(queue_item.title, '#', remote: true) + nested_list,
                  class: "queue_item #{li_class}", id: "queue_item_#{queue_item.id}", title: queue_item.title,
                  data: { queue_item_id: queue_item.id, depth: queue_item.depth }

    end.join.html_safe
  end

  def queue_item_priority_options
    QueueItem.priorities.map do |priority, value|
      [I18n.t("queue_items.priorities.#{priority}"), value]
    end
  end

  def elqueue_window_options(user)
    department_queue = user.department.electronic_queues.enabled.first
    options = department_queue.elqueue_windows.not_chosen.map do |window|
      [window.window_number, window.id]
    end

    if user.elqueue_window.present?
      options << [user.elqueue_window.window_number, user.elqueue_window.id]
    end
    options || []
  end

  def serving_client_ticket_number
    @current_waiting_client&.ticket_number
  end

  def tooltip_text(waiting_client)
    waiting_client.queue_item_ancestors
  end

  def menus_for_client_service_jobs(client)
    client.service_jobs.not_at_archive.map do |service_job|
      job_decorated = service_job.decorate
      menu_item(
        job_decorated.presentation_ticket,
        service_job_path(service_job),
        class: job_decorated.menu_class
      )
    end.join.html_safe
  end

  def dropdown_el_menu_for_user(user)
    menu_items = ''
    title = 'ЭО '
    style = ''
    tooltip = { has_tooltip: false, text: '' }
    @current_elqueue_window = user.elqueue_window
    if user.serving_client?
      @current_waiting_client = @current_elqueue_window.waiting_client
      ticket_num = serving_client_ticket_number
      title = ticket_num
      style = 'color: #424242; font-weight: bold;'
      tooltip[:has_tooltip] = true
      tooltip[:text] = tooltip_text(@current_waiting_client)
      menu_items << menu_item(ticket_num.to_s, show_finish_service_elqueue_window_path(@current_elqueue_window),
                              data: { remote: true })
      if (client = @current_waiting_client.client)
        menu_items << menu_item(client.name_phone, client_path(client), class: 'elqueue-menu-client')
        menu_items << menus_for_client_service_jobs(client)
        menu_items << drop_down_divider
      end
    end

    if user.can_take_a_break?
      if title.start_with?('ЭО ')
        title = 'В ожидании'
        style = 'color: #36b300; font-size: 14px;'
      end
      menu_items << menu_item('Пауза', take_a_break_elqueue_window_path(@current_elqueue_window), method: :patch,
                                                                                              data: { remote: true })
    elsif user.waiting_for_break?
      menu_items << content_tag(:div, 'Пауза после этого клиента', class: 'waiting-for-break_menu-item')
    elsif user.is_on_break?
      if title.start_with?('ЭО ')
        title = 'На паузе'
        style = 'color: #bd0000; font-size: 16px;'
      end
      menu_items << menu_item('Старт', return_from_break_elqueue_window_path(@current_elqueue_window),
                              method: :patch,
                              data: { remote: true })
    end

    menu_items << menu_item("Окно: #{@current_elqueue_window.window_number}", select_window_elqueue_windows_path,
                            data: { remote: true })
    elqueue = user.electronic_queue
    menu_items << menu_item('Выбор талона', manage_tickets_electronic_queue_path(elqueue),
                            class: 'elqueue_active_tickets_button', data: { remote: true })
    menu_items << menu_item('Печать тестового талона',
                            test_printing_waiting_clients_path(electronic_queue_id: elqueue),
                            data: { remote: true })

    custom_drop_down(title.to_s, style: style, tooltip: tooltip) do
      menu_items.html_safe
    end
  end

  def finalized_ticket_options(queue)
    WaitingClient.in_queue(queue).today.finalized.pluck(:ticket_number, :id)
  end

  # Helpers for iPad views
  def render_queue_tree(queue_items, root, parent_id = false)
    elqueue = queue_items.first.electronic_queue
    styles_for_annotation = render_annotation_styles(elqueue)
    styles_for_header = render_header_styles(elqueue)
    styles_for_item = render_item_styles(elqueue)
    container_content = ''
    queue_items.map do |queue_item|
      item_class = root ? 'visible' : 'hidden'
      data_parent = parent_id ? parent_id.to_s : ''
      has_children = queue_item.children.not_archived.any?
      has_phone_input = queue_item.phone_input
      content_tag(:div, class: "queue-item #{item_class}", style: styles_for_item,
                        data: { root: root,
                                item_id: queue_item.id,
                                has_phone_input: has_phone_input,
                                parent_id: data_parent,
                                edge: !(has_children || has_phone_input),
                                disabled: false }) do
        result = ''
        result << content_tag(:h2, queue_item.title, class: 'queue-title', style: styles_for_header)
        result << simple_format(queue_item.annotation, class: 'queue-annotation', style: styles_for_annotation)
        if has_children
          container_content << render_queue_tree(queue_item.children.not_archived, false, queue_item.id)
        elsif queue_item.phone_input
          container_content << render_create_ticket_phone_form(queue_item)
        else
          result << render_create_ticket_form(queue_item)
        end
        result.html_safe
      end
    end.join.html_safe + container_content.html_safe
  end

  def render_create_ticket_phone_form(queue_item)
    elqueue = queue_item.electronic_queue
    styles_for_item = render_item_styles(elqueue)
    styles_for_annotation = render_annotation_styles(elqueue)
    styles_for_header = render_header_styles(elqueue)
    content_tag(:div, class: 'queue-item-phone hidden', style: styles_for_item,
                      data: {
                        root: false,
                        item_id: queue_item.id,
                        parent_id: queue_item.id,
                        edge: true,
                        disabled: false
                      }) do
      result = ''
      result << content_tag(:h2, queue_item.title, class: 'queue-title', style: styles_for_header)
      result << simple_format(queue_item.annotation, class: 'queue-annotation', style: styles_for_annotation)
      result << content_tag(:div, class: 'create-ticket', data: { parent_queue_item_id: queue_item.id }) do
        form_for(queue_item.queue_tickets.build, url: waiting_clients_path, html: { class: 'create-ticket-form' }) do |f|
          form_content = ''
          form_content << content_tag(:div,
                                      'Не хочу вводить номер телефона',
                                      class: 'create-ticket-button clear-phone')
          form_content << f.hidden_field(:queue_item_id, value: queue_item.id)
          form_content << f.telephone_field(:phone_number, readonly: true, placeholder: 'Номер телефона')
          form_content << content_tag(:div, 'Создать талон', class: 'create-ticket-button')
          form_content.html_safe
        end
      end
      result.html_safe
    end
  end

  def render_create_ticket_form(queue_item)
    content_tag :div, class: 'create-ticket', data: { parent_queue_item_id: queue_item.id } do
      form_for(queue_item.queue_tickets.build, url: waiting_clients_path, html: { class: 'create-ticket-form' }) do |f|
        result = ''
        result << f.hidden_field(:queue_item_id, value: queue_item.id)
        result.html_safe
      end
    end
  end

  def render_annotation_styles(electronic_queue)
    "font-size: #{electronic_queue.annotation_font_size}px; font-weight: #{electronic_queue.annotation_boldness};"
  end

  def render_header_styles(electronic_queue)
    "font-size: #{electronic_queue.header_font_size}px; font-weight: #{electronic_queue.header_boldness};"
  end
  def render_item_styles(electronic_queue)
    "background-color: #{electronic_queue.queue_item_color};"
  end

  # Customize drop_down
  def custom_drop_down(name, style:, tooltip:)
    content_tag :li, class: 'dropdown' do
      custom_drop_down_link(name, style: style, tooltip: tooltip) + custom_drop_down_list { yield }
    end
  end

  def custom_name_and_caret(name)
    "#{name} #{content_tag(:b, class: 'caret', style: 'margin-left: 4px; margin-top: 8px; display: inline-block;') {}}".html_safe
  end

  def custom_drop_down_link(name, style:, tooltip:)
    has_tooltip = tooltip[:has_tooltip]
    classes = 'dropdown-toggle elqueue_navbar_title'
    classes << (has_tooltip ? ' has-tooltip' : '')
    link_to(custom_name_and_caret(name),
            '#',
            class: classes,
            style: style,
            data: {
              toggle: 'dropdown',
              title: tooltip[:text]
            })
  end

  def custom_drop_down_list(&block)
    content_tag :ul, class: 'dropdown-menu', &block
  end

  # Методы для панели управления очередью
  def render_queue_item_row(item, level, electronic_queue)
    content_tag(:tr, class: queue_item_row_classes(item)) do
      if item.has_children?
        content_tag(:td, colspan: 4, class: 'parent-cell', style: "padding-left: #{level * 20}px") do
          item.title
        end
      else
        safe_join([
                    content_tag(:td, style: "padding-left: #{level * 20}px") do
                      item.title
                    end,
                    content_tag(:td) do
                      form_tag(
                        update_windows_electronic_queue_queue_item_path(electronic_queue, item),
                        method: :patch,
                        remote: true,
                        class: 'windows-update-form'
                      ) do
                        content_tag(:div, class: 'panel-form-content') do
                          safe_join([
                                      render_window_selection(item, electronic_queue, 'windows'),
                                      content_tag(:div, '', class: 'spacer'),
                                      content_tag(:div, class: 'submit-container') do
                                        button_tag(
                                          type: 'submit',
                                          class: 'save-windows-btn',
                                          data: { disable_with: '<i class="fa fa-spinner fa-spin"></i>' }
                                        ) do
                                          content_tag(:i, '', class: 'fa fa-floppy-o')
                                        end
                                      end
                                    ])
                        end
                      end
                    end,
                    content_tag(:td) do
                      form_tag(
                        update_windows_electronic_queue_queue_item_path(electronic_queue, item),
                        method: :patch,
                        remote: true,
                        class: 'windows-update-form'
                      ) do
                        content_tag(:div, class: 'panel-form-content') do
                          safe_join([
                                      render_window_selection(item, electronic_queue, 'redirect_windows'),
                                      content_tag(:div, '', class: 'spacer'),
                                      content_tag(:div, class: 'submit-container') do
                                        button_tag(
                                          type: 'submit',
                                          class: 'save-windows-btn',
                                          data: { disable_with: '<i class="fa fa-spinner fa-spin"></i>' }
                                        ) do
                                          content_tag(:i, '', class: 'fa fa-floppy-o')
                                        end
                                      end
                                    ])
                        end
                      end
                    end
                  ])
      end
    end + nested_queue_items(item, level + 1, electronic_queue)
  end

  def nested_queue_items(item, level, electronic_queue)
    return ''.html_safe unless item.has_children?

    safe_join(
      item.children.not_archived.map { |child| render_queue_item_row(child, level, electronic_queue) }
    )
  end

  def queue_item_row_classes(item)
    classes = []
    classes << 'leaf-node' unless item.has_children?
    classes.join(' ')
  end

  def render_window_selection(queue_item, electronic_queue, attribute)
    queue_item_id = queue_item.id
    content_tag(:div, class: 'panel-window-selection') do
      circles_container = content_tag(:div, class: 'circles-container') do
        if attribute == 'windows'
          queue_item_windows = queue_item.windows
        elsif attribute == 'redirect_windows'
          queue_item_windows = queue_item.redirect_windows
        end
        electronic_queue.elqueue_windows
                        .map(&:window_number)
                        .sort
                        .map { |number| render_window_circle(queue_item_id, number, queue_item_windows.include?(number), attribute) }
                        .join
                        .html_safe
      end
      hidden_field = hidden_field_tag("queue_item[#{attribute}][]", nil)

      circles_container + hidden_field
    end
  end

  def render_window_circle(queue_item_id, window_number, selected, attribute)
    content_tag(:div, class: 'circle-checkbox') do
      check_box = check_box_tag("queue_item[#{attribute}][]",
                                window_number,
                                selected,
                                id: "queue_item_#{attribute}_#{queue_item_id}_#{window_number}",
                                class: 'hidden-checkbox')
      label = label_tag("queue_item_#{attribute}_#{queue_item_id}_#{window_number}",
                        window_number,
                        class: 'circle-label')
      check_box + label
    end
  end
end
