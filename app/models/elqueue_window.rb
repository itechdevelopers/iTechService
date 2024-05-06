class ElqueueWindow < ApplicationRecord
  belongs_to :electronic_queue
  has_one :waiting_client, dependent: :nullify
  has_one :user, dependent: :nullify

  validates :window_number, presence: true
end