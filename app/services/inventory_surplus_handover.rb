# frozen_string_literal: true

# Приём излишков: найденное сверх учёта «отгружается» на выбранный склад.
#
#   result = InventorySurplusHandover.call(inventory, lines, store)
#
# Приходный документ не создаётся — по решению заказчика излишек не оформляется
# закупкой. Остаток склада-приёмника увеличивается напрямую, остаток филиала не
# трогаем: лишние штуки физически уезжают, и по учёту на филиале остаётся ровно
# то, что там и числилось.
class InventorySurplusHandover
  Result = Struct.new(:lines, :errors) do
    def success?
      errors.empty?
    end
  end

  def self.call(inventory, lines, store)
    new(inventory, lines, store).call
  end

  def initialize(inventory, lines, store)
    @inventory = inventory
    @lines = lines
    @store = store
  end

  def call
    return failure(:store_required) if store.blank?
    return failure(:nothing_to_accept) if surpluses.empty?

    Inventory.transaction do
      surpluses.each do |line|
        add_to_store(line)
        line.update!(resolution: :accepted, surplus_store: store)
      end
    end

    Result.new(surpluses, [])
  end

  private

  attr_reader :inventory, :lines, :store

  # Уже отгруженные строки пропускаем: их излишек однажды прибавили к складу-
  # приёмнику, и повторный приём начислил бы то же количество второй раз.
  def surpluses
    @surpluses ||= lines.select { |line| line.difference.to_i.positive? && !line.resolution_accepted? }
  end

  def add_to_store(line)
    store_item = StoreItem.where(store_id: store.id, item_id: line.item_id).first_or_initialize
    store_item.quantity = store_item.quantity.to_i + line.difference
    store_item.save!
  end

  def failure(key)
    Result.new([], [I18n.t("inventories.accept_surplus.#{key}")])
  end
end
