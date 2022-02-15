# frozen_string_literal: true

class ImportedSale < ApplicationRecord
  scope :sold_at, ->(period) { where(sold_at: period) }
  belongs_to :device_type, optional: true
  def self.search(params)
    if (search = params[:search]).present?
      ImportedSale.where 'LOWER(imported_sales.serial_number) = :s OR LOWER(imported_sales.imei) = :s',
                         s: search.mb_chars.downcase.to_s
    else
      ImportedSale.none
    end
  end

  def device_type_name
    device_type.present? ? device_type.full_name : '-'
  end

  alias_attribute :date, :sold_at
end
