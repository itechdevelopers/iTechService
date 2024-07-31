class ElqueueTicketMovementPolicy < ApplicationPolicy
  def filter_movements_by_called?
    admin? || superadmin?
  end

  def detailed_ticket_info?
    filter_movements_by_called?
  end
end
