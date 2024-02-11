class ServiceJobPolicy < CommonPolicy
  def create?
    any_manager?(:software, :media, :universal)
  end

  def edit?
    read?
  end

  def show_qr?
    read?
  end

  def update?
    (same_department? || able_to?(:access_all_departments)) &&
      any_manager?(:software, :media, :universal, :technician, :engraver, :api, :supervisor)
  end

  def destroy?
    same_department? && any_admin?
  end

  def create_sale?
    same_department? && any_manager?(:software, :universal)
  end

  def read_tech_notice?
    any_admin?(:technician)
  end

  def write_tech_notice?
    any_admin?(:technician)
  end

  def remove_device_tasks?
    update?
  end

  def repair?
    any_admin?(:technician)
  end

  def view_repair_parts?
    (record.at_done? || record.in_archive?) && (superadmin? || able_to?(:view_repair_parts))
  end

  def stale?
    superadmin? || able_to?(:see_stale_service_jobs)
  end

  def inventory?
    superadmin? || able_to?(:inventory)
  end

  def print_receipt?
    (record.user_id == user.id) or any_admin? or able_to?(:print_receipt)
  end

  def move_transfers?
    user.able_to_move_transfers?
  end

  def archive?
    update?
  end

  def set_keeper?; read?; end

  def work_order?; read?; end

  def completion_act?; read?; end

  def history?; read?; end

  def task_history?; read?; end

  def movement_history?; read?; end
end
