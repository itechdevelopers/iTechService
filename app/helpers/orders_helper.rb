module OrdersHelper

  def order_row_tag(order)
    content_tag(:tr, class: order.status, data: { order_id: order.id }) do
      content_tag(:td, link_to(order.number, order_path(order)), class: 'order_number_column') +
        content_tag(:td, t("orders.statuses.#{order.status}"), class: 'order_status_column') +
        content_tag(:td, t("orders.object_kinds.#{order.object_kind}"), class: 'order_object_kind_column') +
        content_tag(:td, order.object, class: 'order_object_column') +
        content_tag(:td, class: 'order_customer_column') do
          if order.customer_type == 'User'
            order.customer_presentation
          else
            (order.customer.present? ? link_to(order.customer_presentation, client_path(order.customer)) : '-')
          end.html_safe +
            tag(:br, false) +
            order.comment
        end +
        content_tag(:td, class: 'order_created_at_column') do
          l(order.created_at, format: :date_time).html_safe +
            (order.user.present? ? (tag(:br, false) + order.user.short_name) : '')
        end +
        content_tag(:td, class: 'order_actions_column') do
          link_to(icon_tag('edit'), edit_order_path(order), class: 'btn btn-small')
        end
    end.html_safe
  end

  def orders_department_filter_tag
    departments = Department.all.map { |d| [d.id.to_s, d.name] }.to_h
    content_tag(:ul, class: 'nav') do
      content_tag(:li, class: 'dropdown') do
        link_to('#', class: 'dropdown-toggle', 'data-toggle' => 'dropdown') do
          (params[:department].present? ? departments[params[:department]] : Order.human_attribute_name(:department)).html_safe +
            caret_tag
        end +
          content_tag(:ul, class: 'dropdown-menu') do
            content_tag(:li, link_to(t('departments.all'), orders_path(params.except(:department)))) +
              departments.to_a.map { |id, name| content_tag(:li, link_to(name, orders_path(params.merge({ department: id })))) }.join.html_safe
          end
      end
    end
  end

  def orders_object_kind_filter_tag
    content_tag(:ul, class: 'nav') do
      content_tag(:li, class: 'dropdown') do
        link_to('#', class: 'dropdown-toggle', 'data-toggle' => 'dropdown') do
          t("orders.object_kinds.#{(params[:object_kind].blank? ? 'all_kinds' : params[:object_kind])}").html_safe +
            caret_tag
        end +
          content_tag(:ul, class: 'dropdown-menu') do
            content_tag(:li, link_to(t('orders.object_kinds.all_kinds'), orders_path(params.except(:object_kind)))) +
              Order::OBJECT_KINDS.map { |object_kind| content_tag(:li, link_to(t("orders.object_kinds.#{object_kind}"), orders_path(params.merge({ object_kind: object_kind })))) }.join.html_safe
          end
      end
    end
  end

  def orders_status_filter_tag
    content_tag(:ul, class: 'nav') do
      content_tag(:li, class: 'dropdown') do
        link_to('#', class: 'dropdown-toggle', 'data-toggle' => 'dropdown') do
          t("orders.statuses.#{params[:status].blank? ? 'all_statuses' : params[:status]}").html_safe +
            caret_tag
        end +
          content_tag(:ul, class: 'dropdown-menu') do
            content_tag(:li, link_to(t('orders.statuses.all_statuses'), orders_path(params.except(:status)))) +
              Order::STATUSES.map { |status| content_tag(:li, link_to(t("orders.statuses.#{status}"), orders_path(params.merge({ status: status })))) }.join.html_safe
          end
      end
    end
  end

  def button_to_change_order_status(order)
    statuses = Order::NEW_STATUSES.dup
    index = statuses.index(order.status)
    return unless index.present?

    next_status = statuses[statuses.index(order.status).next]
    return unless next_status.present?

    name = t "orders.statuses.short.#{next_status}"
    if next_status == 'archive'
      archive_button(order)
    else
      form_for order, url: change_status_order_path(order), html: { class: 'button_to' }, remote: true do |f|
        hidden_field_tag('order[status]', next_status) +
          f.submit(name, class: 'btn btn-primary btn-small')
      end
    end
  end

  def archive_button(order)
    link_to 'В архив',
            edit_archive_reason_order_path(order),
            remote: true,
            class: 'btn btn-danger button_to_archive'
  end

  def order_payment_method_options
    Order.payment_methods.map do |name, _|
      [Order.human_attribute_name("payment_method.#{name}"), name]
    end
  end

  def last_note(order)
    content_tag(:td, class: "order_note_column", colspan: 7) do
      content_tag(:strong, "#{t('orders.notes.last')}: ") +
        content_tag(:span, class: "last_order_note", data: { order_id: order.id }) do
          trim_text(order.notes&.newest&.content)
        end +
        content_tag(:span, class: "last_order_note_full hidden", data: { order_id: order.id }) do
          order.notes&.newest&.content
        end
    end
  end

  def trim_text(text, max_length = 50)
    return "" if text.nil?
    return text.size > max_length ?
           text[0, max_length] + "..." :
           text
  end

  def order_number_with_external_id(order)
    result = link_to(order.number, order_path(order))
    
    # If order is synced with 1C and has external ID, show it below in green
    sync_record = order.one_c_sync
    if sync_record&.synced? && sync_record.external_id.present?
      result += tag(:br) + 
                content_tag(:small, sync_record.external_id, class: 'text-success')
    end
    
    result.html_safe
  end
end
