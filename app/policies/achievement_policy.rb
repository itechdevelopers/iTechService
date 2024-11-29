class AchievementPolicy < CommonPolicy
  def icon_url?
    superadmin?
  end

  def manage?
    superadmin?
  end
end
