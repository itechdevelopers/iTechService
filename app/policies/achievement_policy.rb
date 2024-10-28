class AchievementPolicy < CommonPolicy
  def icon_url?
    superadmin?
  end
end
