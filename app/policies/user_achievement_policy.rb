class UserAchievementPolicy < CommonPolicy
  def manage?
    superadmin?
  end
end
