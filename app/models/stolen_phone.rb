# frozen_string_literal: true

class StolenPhone < ApplicationRecord
  scope :by_imei, lambda { |imei|
                    includes(item: { features: :feature_type }).where('stolen_phones.imei LIKE :q OR (feature_types.kind = :kind AND features.value LIKE :q)', q: "%#{imei}%", kind: 'imei').references(:feature_types)
                  }

  scope :by_serial_number, lambda { |serial_number|
                             includes(item: { features: :feature_type }).where('LOWER(stolen_phones.serial_number) LIKE :q OR (feature_types.kind = :kind AND LOWER(features.value) LIKE :q)', q: "%#{serial_number.mb_chars.downcase}%", kind: 'serial_number').references(:feature_types)
                           }

  scope :by_client, lambda { |client|
                      includes(:client).where('LOWER(clients.name) LIKE :q OR LOWER(clients.surname) LIKE :q OR clients.phone_number LIKE :q OR clients.full_phone_number LIKE :q OR LOWER(clients.card_number) LIKE :q', q: "%#{client.mb_chars.downcase}%").references(:clients)
                    }

  belongs_to :client, optional: true
  belongs_to :item, optional: true
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :features, through: :item
  attr_accessor :comment

  accepts_nested_attributes_for :comments, allow_destroy: true, reject_if: proc { |attr| attr['content'].blank? }
  delegate :presentation, to: :client, allow_nil: true, prefix: true
  # attr_accessible :imei, :serial_number, :item_id, :client_id, :client_comment, :comment, :comments_attributes
  validates :client, presence: true
  validates_associated :comments

  def self.query(imei: nil, serial_number: nil, client: nil, **)
    stolen_phones = StolenPhone.includes(:client).includes(item: { features: :feature_type })
    stolen_phones = stolen_phones.by_imei(imei) if imei.present?
    stolen_phones = stolen_phones.by_serial_number(serial_number) if serial_number.present?
    stolen_phones = stolen_phones.by_client(client) if client.present?
    stolen_phones
  end

  def self.search(params)
    stolen_phones = StolenPhone.includes(:client).includes(item: { features: :feature_type })
    unless (imei_q = params[:imei_q]).blank?
      stolen_phones = stolen_phones.where(
        'stolen_phones.imei LIKE :q OR (feature_types.kind = :kind AND features.value LIKE :q)', q: "%#{imei_q}%", kind: 'imei'
      ).references(:feature_types)
    end
    unless (serial_number_q = params[:serial_number_q]).blank?
      stolen_phones = stolen_phones.where(
        'LOWER(stolen_phones.serial_number) LIKE :q OR (feature_types.kind = :kind AND LOWER(features.value) LIKE :q)', q: "%#{serial_number_q.mb_chars.downcase}%", kind: 'serial_number'
      ).references(:feature_types)
    end
    unless (client_q = params[:client_q]).blank?
      stolen_phones = stolen_phones.where(
        'LOWER(clients.name) LIKE :q OR LOWER(clients.surname) LIKE :q OR clients.phone_number LIKE :q OR clients.full_phone_number LIKE :q OR LOWER(clients.card_number) LIKE :q', q: "%#{client_q.mb_chars.downcase}%"
      ).references(:clients)
    end
    stolen_phones
  end

  def comment=(content)
    comments.build content: content unless content.blank?
  end

  def imei
    item ? item.imei : self['imei']
  end

  def serial_number
    item ? item.serial_number : self['serial_number']
  end

  def item_presentation
    if item.nil?
      [imei.presence, serial_number.presence].compact.join(' / ')
    else
      [item.name, item.imei, item.serial_number].join(' / ')
    end
  end
end
