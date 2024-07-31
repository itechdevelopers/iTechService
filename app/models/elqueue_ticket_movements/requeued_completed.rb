class ElqueueTicketMovement
  class RequeuedCompleted < ElqueueTicketMovement
    validates :user, presence: true
    validates :priority, presence: true, numericality: { only_integer: true }
  end
end
