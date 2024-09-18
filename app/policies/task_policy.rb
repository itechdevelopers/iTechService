class TaskPolicy < CommonPolicy
  def update_positions?
    superadmin?
  end
end
