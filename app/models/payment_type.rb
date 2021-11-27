# frozen_string_literal: true

class PaymentType < ApplicationRecord
  KINDS = %w[cash cashless mixed credit gift_card].freeze

  scope :cash, -> { where(kind: 'cash') }
  scope :sachless, -> { where(kind: 'cashless') }
  validates_presence_of :name, :kind
  validates_inclusion_of :kind, in: KINDS
end
