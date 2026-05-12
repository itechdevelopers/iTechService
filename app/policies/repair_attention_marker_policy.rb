class RepairAttentionMarkerPolicy < ApplicationPolicy
  def dismiss?
    true
  end

  def start_repair?
    true
  end
end
