class SubstitutePhone < ApplicationRecord
  scope :available, -> { not_archived.where(service_job_id: nil) }
  scope :in_department, ->(department) { where(department_id: department) }
  scope :archived, -> { where(archived: true) }
  scope :not_archived, -> { where(archived: [false, nil]) }

  belongs_to :item, optional: true
  belongs_to :department, optional: true
  belongs_to :service_job, optional: true
  has_many :features, through: :item
  has_many :substitutions, class_name: 'PhoneSubstitution'

  delegate :name, :serial_number, :imei, to: :item

  def self.query(search: nil, archive: nil, **p)
    res = self.search search
    !!archive ? res.archived : res.not_archived
  end

  def self.search(query)
    if query.blank?
      self.all
    else
      self.includes(:features).where('LOWER(features.value) LIKE :q', q: "%#{query.mb_chars.downcase.to_s}%").references(:features)
    end
  end

  def pending_substitution
    substitutions.find_by(withdrawn_at: nil)
  end

  def presentation
    [name, serial_number].compact.join(' / ')
  end

  def issued?
    service_job.present?
  end
end
