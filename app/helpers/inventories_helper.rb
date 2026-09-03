# frozen_string_literal: true

module InventoriesHelper
  # Сколько цветов в палитре подсветки авторов (см. inventories.css.scss).
  AUTHOR_COLORS_COUNT = 8

  # Цвет закрепляется за человеком по его id, а не по порядку появления в
  # ревизии: иначе после перезагрузки страницы или в соседней ревизии тот же
  # технарь оказался бы другого цвета, и подсветка перестала бы что-то значить.
  def inventory_author_color_index(user)
    return 0 if user.blank?

    user.id % AUTHOR_COLORS_COUNT
  end

  # У товароведа после сдачи расхождение важнее авторства: он ищет, где факт
  # разошёлся с учётом, а не кто вписал число. Поэтому красная подсветка
  # перебивает цвет автора.
  def inventory_line_row_class(line, reviewing:)
    return 'inventories__line--discrepancy' if reviewing && line.discrepancy?
    return nil unless line.counted? && line.counted_by

    "inventories__line--author-#{inventory_author_color_index(line.counted_by)}"
  end

  # Какие из групп уровня есть смысл раскрывать: у них есть подгруппы или свои
  # позиции. Считаем на весь уровень разом — по запросу на вопрос, а не на узел:
  # `group.has_children?` в цикле дал бы N+1 на каждой ветке дерева.
  def expandable_group_ids(groups)
    groups = groups.to_a
    return Set.new if groups.empty?

    groups_with_children(groups) | groups_with_products(groups.map(&:id))
  end

  def inventory_lines_progress(inventory)
    t('inventories.index.progress_value',
      counted: inventory.counted_lines_count,
      total: inventory.lines.size)
  end

  private

  # ancestry хранит путь предков строкой, поэтому дети всего уровня находятся
  # одним `IN` по этим путям. unscoped — из-за default_scope с ORDER BY: с ним
  # DISTINCT по одной колонке PostgreSQL не соберёт.
  def groups_with_children(groups)
    child_paths = groups.index_by(&:child_ancestry)

    ProductGroup.unscoped.where(ancestry: child_paths.keys).distinct.pluck(:ancestry)
                .map { |path| child_paths[path].id }.to_set
  end

  def groups_with_products(group_ids)
    Product.where(product_group_id: group_ids).distinct.pluck(:product_group_id).to_set
  end
end
