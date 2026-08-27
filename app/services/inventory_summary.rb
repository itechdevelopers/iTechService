# frozen_string_literal: true

# Итоги ревизии: что посчитали, что списали, что отгрузили излишком.
#
#   summary = InventorySummary.new(inventory)
#   summary.shortage_quantity # => 13
#
# Ничего не денормализуем: после закрытия ревизии строки и документы уже
# неизменяемы, а до закрытия сводка должна показывать текущее положение дел.
class InventorySummary
  def initialize(inventory)
    @inventory = inventory
    @lines = inventory.lines.to_a
  end

  def total_lines
    lines.size
  end

  def counted_lines
    lines.count(&:counted?)
  end

  def discrepancy_lines
    lines.select(&:discrepancy?)
  end

  def shortage_lines
    discrepancy_lines.select { |line| line.difference.negative? }
  end

  def surplus_lines
    discrepancy_lines.select { |line| line.difference.positive? }
  end

  def unresolved_lines
    discrepancy_lines.reject(&:resolution_accepted?)
  end

  def shortage_quantity
    shortage_lines.sum { |line| line.difference.abs }
  end

  def surplus_quantity
    surplus_lines.sum(&:difference)
  end

  # Деньги считаем по снимку себестоимости, а не по текущей цене: ревизию
  # закрывают спустя недели, и новая закупка не должна переоценивать задним
  # числом то, что уже списано.
  def shortage_cost
    shortage_lines.sum { |line| line.difference.abs * (line.snapshot_purchase_price || 0) }
  end

  def surplus_cost
    surplus_lines.sum { |line| line.difference * (line.snapshot_purchase_price || 0) }
  end

  # Куда ушли излишки: склад → сколько штук.
  def surplus_by_store
    surplus_lines.select(&:surplus_store).group_by(&:surplus_store)
                 .transform_values { |grouped| grouped.sum(&:difference) }
  end

  # Кто сколько строк заполнил — по этому видно, вся ли смена участвовала.
  def counters
    lines.select(&:counted_by).group_by(&:counted_by)
         .transform_values(&:size)
         .sort_by { |_user, count| -count }
  end

  def documents
    inventory.inventory_documents.includes(:document).to_a
  end

  private

  attr_reader :inventory, :lines
end
