class OrderPolicy < CommonPolicy
  def create?; true; end

  def manage?
    any_manager?(:universal, :media, :marketing, :technician)
  end

  def destroy?
    manage? || (record.user_id == user.id) || has_role?(:software)
  end

  def change_status?
    manage? || (record.user_id == user.id) || has_role?(:software)
  end

  def edit_archive_reason?
    change_status?
  end

  def update_archive_reason?
    change_status?
  end

  def history?
    manage?
  end

  def manual_sync?
    change_status?
  end

  def sync_status?
    # Same permission as manual_sync - if you can sync, you can check status
    manual_sync?
  end

  def delete_from_one_c?
    change_status?
  end

  # Authorization for 1C API endpoints
  def update_status_from_one_c?
    # Only allow API role users (machine tokens for 1C integration)
    has_role?(:api)
  end

  def read_from_one_c?
    # Allow API role to read order status
    has_role?(:api) || read?
  end
end
