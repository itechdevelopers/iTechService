class TradeInDevice < ApplicationRecord
  include Auditable

  scope :ordered, -> { order :number }
  scope :archived, -> { where archived: true }
  scope :not_archived, -> { where archived: false }
  scope :local, -> { where department_id: Department.current_with_remotes }
  scope :confirmed, -> { where(confirmed: true) }
  scope :unconfirmed, -> { where(confirmed: false) }

  belongs_to :item, optional: true
  belongs_to :client, inverse_of: :trade_in_devices, optional: true
  belongs_to :receiver, class_name: 'User', optional: true
  belongs_to :department, optional: true
  has_many :features, through: :item
  has_many :comments, as: :commentable, dependent: :destroy

  validates_presence_of :received_at, :item, :appraised_value, :appraiser, :bought_device,  :check_icloud

  delegate :name, :presentation, :imei, :serial_number, to: :item
  delegate :name, :color, to: :department, prefix: true, allow_nil: true

  enum replacement_status: { not_replaced: 0, replaced: 1, in_service: 2 }
  audited

  def self.search(query, in_archive: false, department_id: nil, sort_column: nil, sort_direction: :asc)
    result = in_archive ? confirmed.archived : confirmed.not_archived

    if department_id.blank?
      result = result.local
    else
      result = result.where(department_id: department_id)
    end

    unless query.blank?
      result = result.includes(:features, :receiver, item: :product)
                 .where('LOWER(features.value) LIKE :q', q: "%#{query.mb_chars.downcase.to_s}%").references(:features)
    end

    if sort_column
      result.order(sort_column => sort_direction)
    else
      result.ordered
    end
  end

  def client_name
    self['client_name'] || client&.full_name
  end

  def client_phone
    self['client_phone'] || client&.human_phone_number
  end
end
