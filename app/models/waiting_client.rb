class WaitingClient < ApplicationRecord
  belongs_to :queue_item
  belongs_to :client, optional: true
  belongs_to :elqueue_window, optional: true

  validates :status, inclusion: { in: ["waiting", "in_service", "completed", "did_not_come"] }
end