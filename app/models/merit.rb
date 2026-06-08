class Merit < ApplicationRecord
  belongs_to :recipient, class_name: 'User', optional: true
  belongs_to :issued_by, class_name: 'User', optional: true
  belongs_to :fault, optional: true

  scope :by_recipient, ->(recipient) { where(recipient_id: recipient) }
  scope :available, -> { where(exchanged: false) }
  scope :exchanged, -> { where(exchanged: true) }
  scope :ordered, -> { order(date: :desc, created_at: :desc) }

  validates :comment, presence: true
end
