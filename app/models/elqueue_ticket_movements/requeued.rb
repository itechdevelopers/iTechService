class ElqueueTicketMovement
  class Requeued < ElqueueTicketMovement
    validates :user, presence: true
    # Из какого окна талон вернули в очередь
    validates :elqueue_window, presence: true
    # К какому окну прикрепили
    # validates :attached_window
    validates :priority, presence: true, numericality: { only_integer: true }
  end
end