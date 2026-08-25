# frozen_string_literal: true

# Разворачивает выбор номенклатуры («что считать») в пронумерованные строки
# ревизии. Вызывается только у черновика: пересборка стирает прежние строки
# вместе с ручными правками товароведа.
#
#   InventoryLinesBuilder.call(inventory)
class InventoryLinesBuilder
  # Глубина истории для сортировки «по частоте использования».
  USAGE_PERIOD = 6.months

  def self.call(inventory)
    new(inventory).call
  end

  # Сколько строк даст разворот прямо сейчас — для сводки на странице выбора.
  # Считаем тем же кодом, что и сборка: иначе обещанное число разойдётся с
  # полученным списком, как только фильтры разойдутся с этой оценкой.
  def self.preview_count(inventory)
    new(inventory).countable_items.size
  end

  def initialize(inventory)
    @inventory = inventory
  end

  def call
    items = countable_items
    usage = usage_counts(items)

    ordered = sort_items(items, usage)

    Inventory.transaction do
      inventory.lines.destroy_all

      ordered.each_with_index do |item, index|
        InventoryLine.create!(
          inventory: inventory,
          item: item,
          position: index + 1,
          snapshot_name: item.name,
          snapshot_purchase_price: item.purchase_price,
          usage_count: usage[item.id].to_i
        )
      end
    end

    ordered.size
  end

  # Позиции с поэкземплярным учётом отсекаем: StoreItem требует у них
  # quantity == 1, считать их штуками нельзя, и приём расхождения упёрся бы в
  # эту же валидацию. Категория берётся с самого продукта, а не с его группы —
  # они расходятся.
  def countable_items
    products = inventory.selected_products_scope
                        .joins(:product_category)
                        .where(product_categories: { feature_accounting: [false, nil] })

    items = Item.where(product_id: products.select(:id)).includes(:product)
    items = items.where(id: stocked_item_ids) unless inventory.include_zero_remnants?
    items.to_a
  end

  private

  attr_reader :inventory

  # Позиции, которые вообще заведены на этом складе. Нулевые остатки тоже
  # считаются заведёнными: строка StoreItem с quantity 0 значит «когда-то было,
  # сейчас нет» — такую позицию имеет смысл пересчитать.
  def stocked_item_ids
    StoreItem.in_store(inventory.store_id).select(:item_id)
  end

  # Сколько раз запчасть уходила в ремонт за последние полгода — по завершённым
  # работам того же филиала. Ремонты других филиалов не показательны: у каждого
  # свой профиль поломок.
  def usage_counts(items)
    return {} if items.empty?

    RepairPart.joins(repair_task: :device_task)
              .where(item_id: items.map(&:id))
              .where(device_tasks: { done: 1, done_at: USAGE_PERIOD.ago..Time.current })
              .where(repair_task_id: RepairTask.in_department(inventory.department_id))
              .group(:item_id)
              .sum(:quantity)
  end

  def sort_items(items, usage)
    case inventory.sort_mode
    when 'cost_desc'
      # Позиции без цены — в конец: сортировать их как ноль значит утверждать,
      # что они дешёвые, а на деле цена просто не заведена.
      items.sort_by { |item| [-(item.purchase_price || 0), sort_name(item)] }
    when 'usage_desc'
      items.sort_by { |item| [-usage[item.id].to_i, sort_name(item)] }
    else
      items.sort_by { |item| sort_name(item) }
    end
  end

  # Ключ алфавитной сортировки. При включённой опции из названия вырезается имя
  # группы, чтобы «Дисплей iPhone 15 Pro» встал на букву «Д». Отображаемое имя
  # при этом остаётся полным — см. snapshot_name.
  def sort_name(item)
    name = item.name.to_s
    return name.downcase unless inventory.ignore_model_in_sort?

    strip_group_name(name, item.product&.product_group).downcase
  end

  # Названия в базе неоднородны — модель встречается и в начале («iPhone 15 Pro
  # Экран»), и в конце («Батарея iPhone 15»), поэтому вырезаем вхождение, а не
  # отрезаем префикс. Если имя группы не встретилось, поднимаемся к родителям:
  # продукт может лежать в подгруппе, а модель называться уровнем выше.
  def strip_group_name(name, group)
    while group.present?
      stripped = name.gsub(/#{Regexp.escape(group.name)}/i, '').squeeze(' ').strip
      return stripped if stripped.present? && stripped != name

      group = group.parent
    end

    name
  end
end
