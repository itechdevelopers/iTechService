# frozen_string_literal: true

class Location < ApplicationRecord
  CODES = %w[
    archive
    bar
    content
    done
    laser
    repair
    repairmac
    repair_notebooks
    special
    warranty
  ].freeze

  scope :ordered, -> { order('position asc') }
  scope :in_city, ->(city) { where department_id: Department.in_city(city) }
  scope :in_department, ->(department) { where department_id: department }
  scope :for_schedule, -> { where(schedule: true) }
  scope :visible, -> { where hidden: [false, nil] }
  scope :archive, -> { where code: 'archive' }
  scope :bar, -> { where code: 'bar' }
  scope :content, -> { where code: 'content' }
  scope :done, -> { where code: 'done' }
  scope :repair, -> { where code: 'repair' }
  scope :repairmac, -> { where code: 'repairmac' }
  scope :repair_mac_or_ios, -> { where code: %w[repair repairmac] }
  scope :repair_notebooks, -> { where code: 'repair_notebooks' }
  scope :warranty, -> { where code: 'warranty' }
  scope :code_start_with, ->(code) { where('code LIKE ?', "#{code}%") }
  scope :short_term, -> { where storage_term: 3 }
  scope :long_term, -> { where storage_term: 12 }
  scope :termless, -> { where storage_term: nil }

  belongs_to :department, inverse_of: :locations
  has_many :users
  delegate :name, to: :department, prefix: true, allow_nil: true
  delegate :city, to: :department, allow_nil: true
  validates_presence_of :name

  def self.search(params)
    locations = all
    locations = locations.where(department_id: params[:department_id]) if params.key?(:department_id)
    locations = locations.visible unless params[:visible].nil?
    locations
  end

  def self.archive_ids
    Location.archive.pluck(:id)
  end

  def self.allowed_for(user, service_job)
    if user.admin?
      visible
    else
      department = service_job.present? && service_job.department.present? ? service_job.department : Department.current
      visible.where(department_id: department.id)
    end
  end

  def to_s
    name
  end

  def full_name
    path.all.map(&:name).join(' / ')
  end

  def is_done?
    code == 'done'
  end

  def is_archive?
    code == 'archive'
  end

  def is_repair?
    code == 'repair'
  end

  def is_warranty?
    code == 'warranty'
  end

  def is_repair_notebooks?
    code == 'repair_notebooks'
  end

  def is_any_repair?
    code.to_s.start_with?('repair')
  end

  def is_special?
    code == 'special'
  end

  def in_transfer?
    department.is_transfer?
  end
end
