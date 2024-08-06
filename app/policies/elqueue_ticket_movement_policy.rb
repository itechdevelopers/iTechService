class ElqueueTicketMovementPolicy < ApplicationPolicy
  def filter_movements_by_called?
    true
  end

  def detailed_ticket_info?
    true
  end

  def find_ticket_by_called?
    filter_movements_by_called?
  end
end
