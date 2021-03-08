# frozen_string_literal: true

class DeviceType < ActiveRecord::Base
  has_many :service_jobs
  has_one :product, inverse_of: :device_type, dependent: :nullify
  validates :name, presence: true
  # validates :name, uniqueness: true
  has_ancestry

  # scope :not_root, where('ancestry != NULL')
  # scope :for_sale, not_root.and(self.arel_table[:descendants_count].eq(0))

  def full_name
    path.all.map(&:name).join ' '
  end

  def available_for_replacement
    qty_for_replacement - qty_replaced
  end

  def has_imei?
    is_childless? and /iPhone|iPad.*Cellular/i === full_name
  end

  def is_iphone?
    root.name.mb_chars.downcase.to_s.start_with? 'iphone'
  end

  def self.for_sale
    all.select(&:is_childless?).sort_by!(&:full_name)
  end

  def self.search_by_full_name(search)
    res = nil
    all.select do |dt|
      res = dt if dt.ancestry.present? && dt.is_childless? && (dt.full_name == search)
    end
    res
  end
end
