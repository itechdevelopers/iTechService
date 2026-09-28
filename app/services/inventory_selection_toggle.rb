# frozen_string_literal: true

# Переключение узла в дереве «что считать».
#
# В таблице выбора живут только «плюсы»: отметка на группе означает всю её
# ветку целиком. Поэтому снятие галочки внутри отмеченной ветки её
# разворачивает — отметка предка заменяется отметками всех братьев по пути
# вниз, а снятый узел просто остаётся без отметки. Обратно ветка схлопывается,
# как только все дети уровня снова оказались отмечены.
#
# Инвариант: ни у одной отметки нет отмеченного предка. На нём держится и
# отрисовка дерева (узел без своей отметки показан галочкой, если отмечен
# предок), и разворачивание — иначе братья получали бы по второй отметке.
#
#   InventorySelectionToggle.call(inventory, product_group, selected: false)
class InventorySelectionToggle
  def self.call(inventory, selectable, selected:)
    new(inventory, selectable, selected).call
  end

  def initialize(inventory, selectable, selected)
    @inventory = inventory
    @selectable = selectable
    @selected = selected
  end

  def call
    Inventory.transaction { selected ? select! : deselect! }
    # Ассоциации выбора у переданной ревизии после переключения врут: Rails
    # запоминает результат `selected_group_ids` при первом чтении и не
    # сбрасывает его ничем, кроме reload. Без этого сводка на той же странице
    # показала бы состояние до нажатия галочки.
    inventory.reload
  end

  private

  attr_reader :inventory, :selectable, :selected

  def select!
    return if own_mark.present? || marked_ancestor.present?

    clear_subtree_marks
    selections.find_or_create_by(selectable: selectable)
    collapse_upwards(parent_group)
  end

  def deselect!
    if own_mark.present?
      own_mark.destroy
      return
    end

    ancestor = marked_ancestor
    expand(ancestor) if ancestor.present?
  end

  # Разворот ветки: спускаемся от отмеченного предка к снятому узлу и на каждом
  # уровне отмечаем всё, кроме следующего звена пути. Номенклатура выходит той
  # же, что и была, минус снятый узел.
  def expand(ancestor)
    chain_from(ancestor).each_cons(2) do |group, skipped|
      siblings(group, skipped).each { |node| selections.find_or_create_by(selectable: node) }
    end

    selections.find_by(selectable: ancestor)&.destroy
  end

  # Сжатие полностью отмеченного уровня в одну отметку на родителе. Без него
  # «снял позицию — вернул» оставляло бы десятки строк вместо одной, и сводка
  # выбора превратилась бы в простыню имён.
  def collapse_upwards(group)
    while group.present?
      children = group.children.to_a
      products = group.products.to_a
      break if children.empty? && products.empty?
      break unless marked_groups(children).count == children.size &&
                   marked_products(products).count == products.size

      marked_groups(children).destroy_all
      marked_products(products).destroy_all
      selections.find_or_create_by(selectable: group)
      group = group.parent
    end
  end

  # Путь от отмеченного предка до самого узла: группы по порядку сверху вниз,
  # последним звеном — переключаемый узел. Идём по path_ids, а не по выборке из
  # базы: default_scope у ProductGroup сортирует по position, и порядок ветки
  # в выборке потерялся бы.
  def chain_from(ancestor)
    groups = ProductGroup.where(id: ancestor_group_ids).index_by(&:id)
    path = ancestor_group_ids.map { |id| groups[id] }.compact

    path.drop_while { |group| group.id != ancestor.id } + [selectable]
  end

  def siblings(group, skipped)
    nodes = group.children.to_a + group.products.to_a
    nodes.reject { |node| node.id == skipped.id && node.class.name == skipped.class.name }
  end

  # Отметки внутри ветки после отметки самой ветки избыточны — они же ломали бы
  # инвариант, а значит и разворачивание.
  def clear_subtree_marks
    return unless selectable.is_a?(ProductGroup)

    group_ids = selectable.subtree_ids
    selections.groups.where(selectable_id: group_ids).destroy_all
    selections.products.where(selectable_id: Product.where(product_group_id: group_ids).select(:id)).destroy_all
  end

  def own_mark
    @own_mark ||= selections.find_by(selectable: selectable)
  end

  def marked_ancestor
    ids = ancestor_group_ids & selections.groups.pluck(:selectable_id)
    # Ближайший предок — самый глубокий, то есть последний в пути от корня.
    ProductGroup.find_by(id: ids.last)
  end

  # Для группы это её предки, для позиции — её собственная группа и предки той:
  # позиция попадает в ревизию через любую из них.
  def ancestor_group_ids
    @ancestor_group_ids ||=
      case selectable
      when ProductGroup then selectable.ancestor_ids
      else Array(selectable.product_group&.path_ids)
      end
  end

  def parent_group
    selectable.is_a?(ProductGroup) ? selectable.parent : selectable.product_group
  end

  def marked_groups(groups)
    selections.groups.where(selectable_id: groups.map(&:id))
  end

  def marked_products(products)
    selections.products.where(selectable_id: products.map(&:id))
  end

  def selections
    inventory.selections
  end
end
