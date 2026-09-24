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

      # `tree_path` (proc gid → url) позволяет переиспользовать дерево на других
      # страницах (напр. «Временные нормативы»), не завязываясь на repair_services.
      # Ссылки всегда remote: true — дерево это jstree-виджет, клик по узлу грузит
      # таблицу через Rails UJS (см. repair_groups.js.coffee); полная перезагрузка
      # jstree недоступна.
      path = if options[:tree_path]
               options[:tree_path].call(repair_group.id)
             elsif params[:action] == 'archived'
               archived_repair_services_path(options)
             else
               repair_services_path(options)
             end
      content_tag :li, link_to(repair_group.name, path, remote: true) + nested_list,
                  class: "repair_group #{li_class}", id: "repair_group_#{repair_group.id}", title: repair_group.name,
                  data: {repair_group_id: repair_group.id, depth: repair_group.depth}

    end.join.html_safe
  end

  # Группы для выпадающих списков: плоский список пар [подпись, группа] в порядке
  # обхода дерева. `RepairGroup.not_archived` сам по себе приходит из базы без
  # ORDER BY, то есть в физическом порядке строк — он меняется после каждого
  # UPDATE, и список выглядит перетасованным.
  def ordered_repair_groups(scope = RepairGroup.not_archived)
    groups = scope.to_a
    children = groups.group_by(&:parent_id)
    # Родитель мог быть архивирован отдельно от потомка — такой потомок иначе
    # выпал бы из списка совсем, поэтому считаем его корнем.
    known_ids = groups.map(&:id)
    roots = groups.reject { |group| known_ids.include?(group.parent_id) }

    labeled_repair_groups(roots, children)
  end

  # Виды ремонта для `grouped_select`: [[подпись группы, [[название, id], ...]], ...].
  # Услуги висят на дочерних группах, поэтому корни без услуг выкидываем —
  # иначе в списке остаются заголовки, по которым нечего выбрать.
  def repair_services_grouped_collection(only_active_services: false, except_ids: [])
    scope = RepairGroup.not_archived.includes(:repair_services)

    ordered_repair_groups(scope).map { |label, group|
      services = group.repair_services.to_a
      services = services.reject(&:archived?) if only_active_services
      services = services.reject { |service| except_ids.include?(service.id) }
      options = services.sort_by { |service| repair_natural_sort_key(service.name) }
                        .map { |service| [service.name, service.id] }
      [label, options]
    }.reject { |_label, options| options.empty? }
  end

  def repair_groups_options
    ordered_repair_groups.map { |label, group| [label, group.id] }
  end

  private

  def labeled_repair_groups(nodes, children, prefix = nil)
    nodes.sort_by { |group| repair_group_sort_key(group) }.flat_map do |group|
      label = [prefix, group.name].compact.join(' / ')
      [[label, group]] + labeled_repair_groups(children.fetch(group.id, []), children, label)
    end
  end

  # Айфоны — основной поток ремонтов, их держим в начале списка, остальное по алфавиту.
  def repair_group_sort_key(group)
    [group.name.to_s =~ /iphone/i ? 0 : 1, repair_natural_sort_key(group.name)]
  end

  # Числа внутри названия сравниваем как числа, иначе «iPhone 8» встаёт после
  # «iPhone 15», а регистр раскладывает латиницу до кириллицы вперемешку
  # (в базе C-collation, 'M' < 'i').
  def repair_natural_sort_key(name)
    name.to_s.downcase.scan(/\d+|\D+/).map do |chunk|
      chunk =~ /\A\d/ ? [1, chunk.to_i, ''] : [0, 0, chunk]
    end
  end
end
