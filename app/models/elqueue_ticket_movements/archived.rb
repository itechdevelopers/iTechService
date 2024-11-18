class ElqueueTicketMovement::Archived < ElqueueTicketMovement
  validates :user, presence: true
end
