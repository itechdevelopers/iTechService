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
end