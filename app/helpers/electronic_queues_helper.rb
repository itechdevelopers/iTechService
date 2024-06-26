module ElectronicQueuesHelper
  def queue_items_trees_tag(queue_items, current_id=nil, options={})
    queue_items.map do |queue_item|
      queue_items_tree_tag queue_item, current_id, options
    end.join.html_safe
  end

  def queue_items_tree_tag(queue_item, current_id=nil, options={})
    content_tag :ul, nested_queue_items_list(queue_item.subtree.arrange(order: :position), current_id, options),
                class: 'queue_items_tree unstyled', id: "queue_items_tree_#{queue_item.id}",
                data: { root_id: queue_item.id, queue_item_id: current_id, opened: [current_id] }
  end

  def nested_queue_items_list(queue_items, current_id=nil, options={})
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

  def serving_client_ticket_number(window)
    window.waiting_client&.ticket_number
  end

  def dropdown_el_menu_for_user(user)
    menu_items = ''
    title = 'ЭО '
    style = ''
    if user.serving_client?
      ticket_num = serving_client_ticket_number(user.elqueue_window)
      title = ticket_num
      style = 'color: #424242; font-weight: bold;'
      menu_items << menu_item(ticket_num.to_s, show_finish_service_elqueue_window_path(user.elqueue_window),
                              data: { remote: true })
    end

    if user.can_take_a_break?
      if title.start_with?('ЭО ')
        title = 'В ожидании'
        style = 'color: #36b300; font-size: 14px;'
      end
      menu_items << menu_item('Пауза', take_a_break_elqueue_window_path(user.elqueue_window), method: :patch,
                                                                                              data: { remote: true })
    elsif user.waiting_for_break?
      menu_items << content_tag(:div, 'Пауза после этого клиента', class: 'waiting-for-break_menu-item')
    elsif user.is_on_break?
      if title.start_with?('ЭО ')
        title = 'На паузе'
        style = 'color: #bd0000; font-size: 16px;'
      end
      menu_items << menu_item('Старт', return_from_break_elqueue_window_path(user.elqueue_window),
                              method: :patch,
                              data: { remote: true })
    end

    menu_items << menu_item("Окно: #{user.elqueue_window.window_number}", select_window_elqueue_windows_path,
                            data: { remote: true })
    menu_items << menu_item('Выбор талона', manage_tickets_electronic_queue_path(user.electronic_queue),
                            class: 'elqueue_active_tickets_button', data: { remote: true })

    custom_drop_down(title.to_s, style: style) do
      menu_items.html_safe
    end
  end

  def finalized_ticket_options(queue)
    WaitingClient.in_queue(queue).today.finalized.pluck(:ticket_number, :id)
  end

  # Helpers for iPad views
  def render_queue_tree(queue_items, root, parent_id=false)
    elqueue = queue_items.first.electronic_queue
    styles_for_annotation = render_annotation_styles(elqueue)
    styles_for_header = render_header_styles(elqueue)
    styles_for_item = render_item_styles(elqueue)
    container_content = ''
    queue_items.map do |queue_item|
      item_class = root ? 'visible' : 'hidden'
      data_parent = parent_id ? parent_id.to_s : ''
      has_children = queue_item.children.any?
      content_tag(:div, class: "queue-item #{item_class}", style: styles_for_item,
                        data: { root: root, item_id: queue_item.id, parent_id: data_parent, edge: !has_children }) do
        result = ''
        result << content_tag(:h2, queue_item.title, class: 'queue-title', style: styles_for_header)
        result << content_tag(:p, queue_item.annotation, class: 'queue-annotation', style: styles_for_annotation)
        if has_children
          container_content << render_queue_tree(queue_item.children, false, queue_item.id)
        else
          result << render_create_ticket_form(queue_item)
        end
        result.html_safe
      end
    end.join.html_safe + container_content.html_safe
  end

  def render_create_ticket_form(queue_item)
    content_tag :div, class: 'create-ticket', data: { parent_queue_item_id: queue_item.id } do
      form_for(queue_item.queue_tickets.build, url: waiting_clients_path, html: { class: 'create-ticket-form' }) do |f|
        result = ''
        result << f.hidden_field(:queue_item_id, value: queue_item.id)
        # if queue_item.phone_input
        #   result << content_tag(:div, class: 'elqueue-inline-fields') do
        #     inline_result = ''
        #     inline_result << f.select(:country_code, country_phone_code_options, { selected: 'RU' },
        #                               class: 'elqueue-country-code-select').join('')
        #     inline_result << f.telephone_field(:phone_number, placeholder: '123-345-6789', class: 'client-phone')
        #     inline_result.html_safe
        #   end
        # end
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
  def custom_drop_down(name, style:)
    content_tag :li, :class => 'dropdown' do
      custom_drop_down_link(name, style: style) + custom_drop_down_list { yield }
    end
  end

  def custom_name_and_caret(name)
    "#{name} #{content_tag(:b, :class => "caret", style: "margin-left: 4px; margin-top: 8px; display: inline-block;") {
}}".html_safe
  end

  def custom_drop_down_link(name, style:)
    link_to(custom_name_and_caret(name), '#', :class => 'dropdown-toggle elqueue_navbar_title', style: style, 'data-toggle' => 'dropdown')
  end

  def custom_drop_down_list(&block)
    content_tag :ul, :class => 'dropdown-menu', &block
  end
end