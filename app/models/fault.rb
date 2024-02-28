class Fault < ApplicationRecord
  belongs_to :causer, class_name: 'User', optional: true
  belongs_to :issued_by, class_name: 'User', optional: true
  belongs_to :kind, class_name: 'FaultKind', optional: true

  scope :by_causer, ->(causer) { where(causer_id: causer) }
  scope :by_kind, ->(kind) { where(kind_id: kind) }
  scope :by_date, ->(date) { where(date: date) }
  scope :on_date, ->(date) { where('date <= ?', date) }
  scope :ordered, -> { order date: :desc }
  scope :active, -> { where(expired: false) }
  scope :expired, -> { where(expired: true) }
  scope :expireable, -> { where(kind: FaultKind.expireable) }

  delegate :name, :icon, :icon_url, :financial?, :description, to: :kind, allow_nil: true
end
