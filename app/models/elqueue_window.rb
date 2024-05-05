class ElqueueWindow < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :electronic_queue
  has_one :waiting_client, dependent: :nullify

  validates :window_number, presence: true
end