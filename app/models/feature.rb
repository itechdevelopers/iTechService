# frozen_string_literal: true

class Feature < ActiveRecord::Base
  scope :imei, -> { includes(:feature_type).where(feature_types: { kind: 'imei' }) }
  scope :serial_number, -> { includes(:feature_type).where(feature_types: { kind: 'serial_number' }) }
  # scope :search, ->(query) { where('LOWER(features.value) LIKE :q OR LOWER(service_jobs.serial_number) LIKE :q OR LOWER(service_jobs.imei) LIKE :q', q: "%#{service_job_q.mb_chars.downcase.to_s}%").references(:features) }
  scope :search, ->(query) { where('LOWER(value) LIKE :q', q: "%#{query.mb_chars.downcase}%") }

  belongs_to :feature_type
  belongs_to :item, inverse_of: :features
  # attr_accessible :value, :item, :item_id, :feature_type, :feature_type_id
  validates_presence_of :value, :feature_type
  validates_uniqueness_of :value, scope: [:feature_type_id], unless: proc { |feature| feature.value == '?' }
  validates_length_of :value, is: 15, if: proc { |feature| feature.is_imei? && feature.value != '?' }
  delegate :name, :kind, :is_imei?, to: :feature_type, allow_nil: true

  default_scope { order('feature_type_id asc') }

  def as_json(_options = {})
    {
      id: id,
      kind: kind,
      name: name,
      value: value
    }
  end
end
