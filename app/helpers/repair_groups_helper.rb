module RepairGroupsHelper

  def repair_groups_trees_tag(repair_groups, current_id=nil, options={})
    repair_groups.map do |repair_group|
      repair_groups_tree_tag repair_group, current_id, options
    end.join.html_safe
  end

  def repair_groups_tree_tag(repair_group, current_id=nil, options={})
    tree_class = options[:archived] ? 'repair_groups_tree unstyled archived' : 'repair_groups_tree unstyled'
    
    # Filter out archived groups from subtree when not in archived mode
    subtree = if options[:archived]
                repair_group.subtree
              else
                repair_group.subtree.not_archived
              end
    
    content_tag :ul, nested_repair_groups_list(subtree.arrange(order: :name), current_id, options),
                class: tree_class, id: "repair_groups_tree_#{repair_group.id}",
                data: {root_id: repair_group.id, repair_group_id: current_id, opened: [current_id], archived: options[:archived]}
  end

  def nested_repair_groups_list(repair_groups, current_id=nil, options={})
    repair_groups.map do |repair_group, sub_repair_groups|
      is_current = repair_group.id == current_id.to_i
      li_class = 'opened'
      li_class << ' current' if is_current
      nested_list = content_tag(:ul, nested_repair_groups_list(sub_repair_groups, current_id, options))
      options[:group] = repair_group.id

      path = if params[:action] == 'archived'
               archived_repair_services_path(options)
             else
               repair_services_path(options)
             end
      content_tag :li, link_to(repair_group.name, path, remote: true) + nested_list,
                  class: "repair_group #{li_class}", id: "repair_group_#{repair_group.id}", title: repair_group.name,
                  data: {repair_group_id: repair_group.id, depth: repair_group.depth}

    end.join.html_safe
  end
end
