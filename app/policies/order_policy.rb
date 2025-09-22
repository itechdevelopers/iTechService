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
end
