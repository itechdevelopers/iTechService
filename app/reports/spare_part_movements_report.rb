class SparePartMovementsReport < BaseReport
  attr_reader :spare_part_id

  params %i[start_date end_date department_id spare_part_id]

  def call
    deps = department.map(&:name).join(" - ")
    @result = []

    parts = Product.where(id: spare_part_id)
    parts.each do |part|
      res = {}
      res[:spare_part] = part.name
      res[:dates] = "#{start_date} - #{end_date}"
      res[:departments] = deps
      res[:movements] = movements_for_sp(part)

      @result << res
    end

    @result
  end

  def spare_part_id=(value)
    @spare_part_id = [value].flatten.reject(&:blank?)
  end

  private

  def movements_for_sp(sp)
    movements = []
    purchases = Purchase.where(date: period, store_id: all_department_store_ids)
                        .joins(:items)
                        .where(items: { product_id: spare_part_id })
                        .distinct
    purchases.each do |p|
      res = {}
      res[:date] = p.date.strftime('%d.%m.%Y')
      res[:department] = p.store.present? ? p.store.name : "-"
      res[:quantity] = p.batches.where(item: product_items).first.quantity
      res[:doc_type] = "Приход"
      res[:doc_number] = "№#{p.id}"

      movements << res
    end

    moves = MovementAct.where(store_id: all_department_store_ids)
                       .or(MovementAct.where(dst_store_id: all_department_store_ids))
                       .where(date: period)
                       .joins(:movement_items)
                       .where(movement_items: { item: product_items })
                       .distinct
    moves.each do |m|
      res = {}
      res[:date] = m.date.strftime('%d.%m.%Y')
      res[:department] = "#{m.store.name} - #{m.dst_store.name}"
      res[:quantity] = m.movement_items.where(item: product_items).first.quantity
      res[:doc_type] = "Перемещение"
      res[:doc_number] = "№#{m.id}"

      movements << res
    end

    deductions = DeductionAct.where(date: period, store_id: all_department_store_ids)
                             .joins(:deduction_items)
                             .where(deduction_items: { item: product_items })
                             .distinct
    deductions.each do |d|
      res = {}
      res[:date] = d.date.strftime('%d.%m.%Y')
      res[:department] = "#{d.store.name}"
      res[:quantity] = d.deduction_items.where(item: product_items).first.quantity
      res[:doc_type] = "Списание"
      res[:doc_number] = "№#{d.id}"

      movements << res
    end

    movements
  end

  def all_department_store_ids
    department.map(&:stores).flatten.map { |st| st.id }
  end

  def product_items
    @items ||= Item.where(product_id: spare_part_id)
  end
end