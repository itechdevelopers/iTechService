class RepairServicePolicy < CommonPolicy
  def choose?
    any_manager?(:technician)
  end

  def select?; choose?; end

  def mass_update?
    superadmin? || able_to?(:manage_stocks)
  end

  def see_quantity?
    superadmin? || able_to?(:show_spare_parts_qty)
  end
end
