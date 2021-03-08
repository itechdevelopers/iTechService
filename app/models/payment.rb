# frozen_string_literal: true

class Payment < ActiveRecord::Base
  KINDS = %w[cash card credit certificate trade_in].freeze

  scope :in_department, ->(department) { where sale_id: Sale.in_department(department) }
  scope :cash, -> { where(kind: 'cash') }
  scope :card, -> { where(kind: 'card') }
  scope :credit, -> { where(kind: 'credit') }
  scope :certificate, -> { where(kind: 'certificate') }
  scope :gift_certificates, -> { where(kind: 'certificate') }
  scope :trade_in, -> { where(kind: 'trade_in') }
  scope :sales, -> { joins(:sale).where(sales: { is_return: false }) }
  scope :returns, -> { joins(:sale).where(sales: { is_return: true }) }

  belongs_to :sale, inverse_of: :payments
  belongs_to :bank
  belongs_to :gift_certificate

  delegate :balance, :nominal, :number, to: :gift_certificate, prefix: true, allow_nil: true
  delegate :name, to: :bank, prefix: true, allow_nil: true
  delegate :is_return, :department, :department_id, to: :sale

  # attr_accessible :value, :kind, :sale_id, :bank_id, :gift_certificate_id, :device_name, :device_number, :client_info, :appraiser, :device_logout

  validates_presence_of :value, :kind
  validates_presence_of :bank, if: :is_by_bank?
  validates_presence_of :gift_certificate, if: 'is_gift_certificate? and !is_return'
  validates_presence_of :device_name, :device_number, :client_info, :appraiser, if: :is_trade_in?
  validates_acceptance_of :device_logout, if: :is_trade_in?
  validates_numericality_of :value, greater_than: 0
  validates_numericality_of :value, less_than_or_equal_to: :gift_certificate_balance,
                                    if: 'is_gift_certificate? and !is_return'
  before_validation :clear_unnecessary_attributes

  def is_cash?
    kind == 'cash'
  end

  def is_credit?
    kind == 'credit'
  end

  def is_gift_certificate?
    kind == 'certificate'
  end

  def is_trade_in?
    kind == 'trade_in'
  end

  def is_by_bank?
    %w[card credit].include? kind
  end

  def attributes_hash
    result = {}
    result[:is_return] = is_return
    result[:value] = value
    result[:bank] = bank_name if is_by_bank?
    result[:gift_certificate] = gift_certificate_number if is_gift_certificate?
    if is_trade_in?
      result[:device_name] = device_name
      result[:device_number] = device_number
      result[:client_info] = client_info
      result[:appraiser] = appraiser
    end
    result
  end

  private

  def clear_unnecessary_attributes
    self.bank_id = nil unless is_by_bank?
    self.gift_certificate_id = nil unless is_gift_certificate?
    self.device_name = self.device_number = self.client_info = self.appraiser = nil unless is_trade_in?
  end
end
