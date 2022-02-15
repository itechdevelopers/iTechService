class Fault < ApplicationRecord
  belongs_to :causer, class_name: 'User', optional: true
  belongs_to :kind, class_name: 'FaultKind', optional: true

  scope :ordered, -> { order date: :desc }
  # scope :expireable, -> { includes(:kind).where(fault_kinds: {is_permanent: false}).references(:fault_kinds) }
  scope :expireable, -> { where(kind: FaultKind.expireable) }

  delegate :name, :icon, :icon_url, :financial?, :description, to: :kind, allow_nil: true
end
