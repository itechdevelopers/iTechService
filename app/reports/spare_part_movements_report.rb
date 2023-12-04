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
                        .where(items: { product_id: sp.id })
                        .distinct
    purchases.each do |p|
      res = {}
      res[:date] = p.date
      res[:department] = p.store.present? ? p.store.name : "-"
      res[:quantity] = p.batches.where(item: product_items(sp)).first.quantity
      res[:doc_type] = "Приход"
      res[:doc_number] = "№#{p.id}"
      res[:comment] = p.comment.present? ? p.comment : "-"

      movements << res
    end

    moves = MovementAct.where(store_id: all_department_store_ids)
                       .or(MovementAct.where(dst_store_id: all_department_store_ids))
                       .where(date: period)
                       .joins(:movement_items)
                       .where(movement_items: { item: product_items(sp) })
                       .distinct
    moves.each do |m|
      res = {}
      res[:date] = m.date
      res[:department] = "#{m.store.name} &#8680; #{m.dst_store.name}"
      res[:quantity] = m.movement_items.where(item: product_items(sp)).first.quantity
      res[:doc_type] = m.dst_store.kind == "defect_sp" ? "Брак" : "Перемещение"
      res[:doc_number] = "№#{m.id}"
      res[:comment] = m.comment.present? ? m.comment : "-"

      movements << res
    end

    deductions = DeductionAct.where(date: period, store_id: all_department_store_ids)
                             .joins(:deduction_items)
                             .where(deduction_items: { item: product_items(sp) })
                             .distinct
    deductions.each do |d|
      res = {}
      res[:date] = d.date
      res[:department] = "#{d.store.name}"
      res[:quantity] = d.deduction_items.where(item: product_items(sp)).first.quantity
      res[:doc_type] = "Списание"
      res[:doc_number] = "№#{d.id}"
      res[:comment] = d.comment.present? ? d.comment : "-"

      movements << res
    end

    service_jobs = ServiceJob.done
                             .where(done_at: period, department: department)
                             .joins(:repair_parts)
                             .where(repair_parts: { item: product_items(sp) })
                             .distinct
    service_jobs.each do |s|
      res = {}
      res[:date] = s.done_at
      res[:department] = "#{s.department.name}"
      res[:quantity] = s.repair_parts.where(item: product_items(sp)).first.quantity
      res[:doc_type] = "Реализация"
      res[:doc_number] = "№#{s.id}"
      res[:comment] = "-"

      movements << res
    end

    movements.sort_by { |mv| mv[:date] }.each { |mv| mv[:date] = mv[:date].strftime("%d.%m.%Y") }
  end

  def all_department_store_ids
    department.map(&:stores).flatten.map { |st| st.id }
  end

  def product_items(sp)
    Item.where(product_id: sp.id)
  end
end