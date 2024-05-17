module ElectronicQueuesHelper
  def queue_items_trees_tag(queue_items, current_id=nil, options={})
    queue_items.map do |queue_item|
      queue_items_tree_tag queue_item, current_id, options
    end.join.html_safe
  end

  def queue_items_tree_tag(queue_item, current_id=nil, options={})
    content_tag :ul, nested_queue_items_list(queue_item.subtree.arrange(order: :position), current_id, options),
                class: 'queue_items_tree unstyled', id: "queue_items_tree_#{queue_item.id}",
                data: {root_id: queue_item.id, queue_item_id: current_id, opened: [current_id]}
  end

  def nested_queue_items_list(queue_items, current_id=nil, options={})
    queue_items.map do |queue_item, sub_queue_items|
      is_current = queue_item.id == current_id.to_i
      li_class = 'opened'
      li_class << ' current' if is_current
      nested_list = content_tag(:ul, nested_queue_items_list(sub_queue_items, current_id, options))
      options[:group] = queue_item.id

      content_tag :li, link_to(queue_item.title, "#", remote: true) + nested_list,
                  class: "queue_item #{li_class}", id: "queue_item_#{queue_item.id}", title: queue_item.title,
                  data: {queue_item_id: queue_item.id, depth: queue_item.depth}

    end.join.html_safe
  end

  def queue_item_priority_options
    QueueItem.priorities.map do |priority, value|
      [I18n.t("queue_items.priorities.#{priority}"), value]
    end
  end

  def elqueue_window_options(user)
    department_queue = user.department.electronic_queues.enabled.first
    department_queue.elqueue_windows.map do |window|
      [window.window_number, window.id]
    end
  end

  def serving_client_ticket_number(window)
    window.waiting_client&.ticket_number
  end

  # Helpers for iPad views
  def render_queue_tree(queue_items, root, parent_id=false)
    styles_for_annotation = render_annotation_styles(queue_items.first.electronic_queue)
    styles_for_header = render_header_styles(queue_items.first.electronic_queue)
    container_content = ""
    queue_items.map do |queue_item|
      item_class = root ? "visible" : "hidden"
      data_parent = parent_id ? "#{parent_id}" : ""
      has_children = queue_item.children.any?
      content_tag(:div, class: "queue-item #{item_class}", data: {root: root, item_id: queue_item.id, parent_id: data_parent, edge: !has_children}) do
        result = ""
        result << content_tag(:h2, queue_item.title, class: "queue-title", style: styles_for_header)
        result << content_tag(:p, queue_item.annotation, class: "queue-annotation", style: styles_for_annotation)
        if has_children
          container_content << render_queue_tree(queue_item.children, false, queue_item.id)
        else
          container_content << render_create_ticket_form(queue_item)
        end
        result.html_safe
      end
    end.join.html_safe + container_content.html_safe
  end

  def render_create_ticket_form(queue_item)
    content_tag :div, class: "create-ticket hidden", data: {parent_id: queue_item.id} do
      form_for(queue_item.queue_tickets.build, url: waiting_clients_path, html: {class: "create-ticket-form"}) do |f|
        result = ""
        result << f.hidden_field(:queue_item_id, value: queue_item.id)
        result << f.text_field(:client_name, placeholder: "Имя клиента", class: "client-name")
        result << f.text_field(:phone_number, placeholder: "Телефон клиента", class: "client-phone", inputmode: "numeric") if queue_item.phone_input
        result << f.submit("Создать талон", class: "create-ticket-button")
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
end