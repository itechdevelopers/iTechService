class ElqueueTicketMovement
  class NewTicket < ElqueueTicketMovement
    validates :priority, presence: true, numericality: { only_integer: true }
  end
end
