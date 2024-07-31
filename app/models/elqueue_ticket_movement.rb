class ElqueueTicketMovement < ApplicationRecord
  belongs_to :waiting_client
  belongs_to :elqueue_window, optional: true
  belongs_to :user, optional: true
  belongs_to :electronic_queue
end
