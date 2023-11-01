class DeviceNotePolicy < BasePolicy
  def create?; true; end

  def update?
    superadmin? || record.user_id == current_user
  end
end
