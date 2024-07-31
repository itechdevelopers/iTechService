class ElqueueTicketMovement
  class Called < ElqueueTicketMovement
    validates :user, presence: true
    validates :elqueue_window, presence: true
  end
end
