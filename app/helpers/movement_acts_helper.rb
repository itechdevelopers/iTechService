# frozen_string_literal: true

module MovementActsHelper
  def movement_act_quantity_stores
    @movement_act_quantity_stores ||= Store.for_movement_acts.to_a
  end

  # Название подразделения короче названия склада и как раз то, чем товаровед
  # различает точки. Тип склада дописываем только когда у одного подразделения
  # отмечено несколько складов — иначе заголовки колонок совпали бы.
  def movement_act_store_label(store)
    label = movement_act_store_base_label(store)
    return label unless movement_act_store_label_counts[label].to_i > 1

    [label, human_store_kind(store)].compact.join(', ')
  end

  # {store_id => quantity} — один запрос на строку вместо запроса на каждый склад.
  # Остаток считаем по продукту, а не по item'у: так же, как существующая
  # колонка «На складе» (Product#quantity_in_store).
  def movement_item_store_quantities(movement_item)
    product_id = movement_item.try(:product).try(:id)
    return {} if product_id.blank? || movement_act_quantity_stores.empty?

    StoreItem.joins(:item)
             .where(items: { product_id: product_id },
                    store_id: movement_act_quantity_stores.map(&:id))
             .group(:store_id)
             .sum(:quantity)
  end

  private

  def movement_act_store_base_label(store)
    store.department_name.presence || store.name
  end

  def movement_act_store_label_counts
    @movement_act_store_label_counts ||=
      movement_act_quantity_stores
      .group_by { |store| movement_act_store_base_label(store) }
      .map { |label, stores| [label, stores.size] }
      .to_h
  end
end
