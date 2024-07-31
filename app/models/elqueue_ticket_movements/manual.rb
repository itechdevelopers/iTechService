class ElqueueTicketMovement
  class Manual < ElqueueTicketMovement
    validates :user, presence: true
  end
end
