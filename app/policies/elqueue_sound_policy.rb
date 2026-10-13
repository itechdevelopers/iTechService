class ElqueueSoundPolicy < ApplicationPolicy
  # Записи общие для всех очередей, поэтому ими распоряжается тот же круг людей,
  # что настраивает сами очереди.
  def manage?
    ElectronicQueuePolicy.new(user, ElectronicQueue).manage?
  end

  # ТВ открыт под технической учёткой без особых прав.
  def audio?
    true
  end
end
