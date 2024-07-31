class ElqueueTicketMovement
  class TimeoutMoved  < ElqueueTicketMovement
    validates :priority, presence: true, numericality: { only_integer: true }
  end
end