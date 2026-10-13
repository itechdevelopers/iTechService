module RepairServicesHelper

  def spare_part_row_class(spare_part)
    case spare_part.remnant_s(current_user.spare_parts_store)
      when 'none' then 'error'
      when 'low' then 'warning'
      when 'many' then 'success'
      else ''
    end
  end

  def repair_service_warranty_display(repair_service)
    return '-' unless repair_service.spare_parts.present?

    warranty_terms = repair_service.spare_parts.map(&:warranty_term).compact
    return '-' if warranty_terms.empty?

    max_warranty = warranty_terms.max
    max_warranty.present? && max_warranty > 0 ? "#{max_warranty} мес." : '-'
  end

  # Тот же стандарт времени, что приёмщик видит при выборе вида ремонта в заказ-наряде:
  # у «сложных» видов вместо одного значения задан диапазон от–до (в минутах).
  def repair_service_time_display(repair_service)
    from = repair_service.time_standard_from.to_i
    to = repair_service.time_standard_to.to_i
    single = repair_service.time_standard.to_i

    if from.positive? && to.positive?
      "#{human_repair_duration(from * 60)} – #{human_repair_duration(to * 60)}"
    elsif single.positive?
      human_repair_duration(single * 60)
    end
  end

  # Кнопки фильтра — только группы, которые встречаются у видов ремонта в таблице.
  # reorder(nil): у RepairService сортировка в default_scope, а поиск добавляет DISTINCT,
  # и Postgres не даёт сортировать DISTINCT-подзапрос по колонке вне списка выборки.
  def repair_cause_groups_for(repair_services)
    cause_group_ids = RepairCause.joins(:repair_services)
                                 .where(repair_services: { id: repair_services.reorder(nil).select(:id) })
                                 .select(:repair_cause_group_id)
    RepairCauseGroup.where(id: cause_group_ids).order(:title)
  end

end
