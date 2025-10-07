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

end
