# frozen_string_literal: true

class Department < ApplicationRecord
  ROLES = {
    0 => 'main',
    1 => 'branch',
    2 => 'store',
    3 => 'remote',
    4 => 'transfer'
  }.freeze

  default_scope { active.order('departments.id asc') }
  scope :branches, -> { where(role: 1) }
  scope :selectable, -> { where(role: [0, 1, 3, 4]) }
  scope :real, -> { where(role: [0, 1, 3]) }
  scope :main_branches, -> { where(role: [0, 1]) }
  scope :in_city, ->(city) { where(city: city) }
  scope :active, -> { where(archive: [false, nil]) }

  belongs_to :city
  belongs_to :brand
  has_many :users, dependent: :nullify
  has_many :stores, dependent: :nullify
  has_many :cash_drawers, dependent: :nullify
  has_many :settings, dependent: :destroy
  has_many :service_jobs, inverse_of: :department
  has_many :locations, inverse_of: :department
  has_many :electronic_queues

  # attr_accessible :name, :short_name, :role, :code, :url, :city_id, :brand_id, :address, :contact_phone, :schedule, :printer, :ip_network
  validates_presence_of :name, :role, :code
  validates :url, presence: true, if: :has_server?
  validate :only_one_main

  delegate :name, to: :city, prefix: true
  delegate :color, to: :city, allow_nil: true
  delegate :name, to: :brand, prefix: true, allow_nil: true
  delegate :logo, to: :brand, allow_nil: true
  delegate :path, :url, to: :logo, prefix: true, allow_nil: true

  before_save :sanitize_code_one_c

  def self.find_by_network(network)
    where('ip_network LIKE ?', "%#{network}%").first
  end

  def self.default
    Department.find_by(code: ENV.fetch('DEPARTMENT_CODE', 'vl')) || Department.first
  end

  def self.current
    User.current&.department || Department.default
  end

  def self.current_with_remotes
    where('code LIKE ?', "#{Department.current.code}%")
  end

  def full_name
    "#{city_name} > #{name}"
  end

  def role_s
    ROLES[role]
  end

  def is_main?
    role.zero?
  end

  def is_branch?
    role == 1
  end

  def is_store?
    role == 2
  end

  def is_remote?
    role == 3
  end

  def is_transfer?
    role == 4
  end

  def has_server?
    role.in? 0..1
  end

  def spare_parts_store
    stores.spare_parts.first
  end

  def defect_sp_store
    stores.defect_sp.first
  end

  def repair_store
    stores.repair.first_or_create(name: 'Ремонт')
  end

  def default_cash_drawer
    cash_drawers.first_or_create name: 'Касса'
  end

  def current_cash_shift
    default_cash_drawer.current_shift
  end

  private

  def sanitize_code_one_c
    self[:code_one_c] = self[:code_one_c].strip if self[:code_one_c].present?
  end

  def only_one_main
    errors.add :role, :main_exists if role.zero? && (Department.where('id <> ? AND role = ?', id, 0).count > 1)
    false
  end
end
