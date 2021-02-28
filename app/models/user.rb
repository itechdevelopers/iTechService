# frozen_string_literal: true

class User < ActiveRecord::Base
  ROLES = %w[
    admin
    software
    media
    technician
    marketing
    developer
    supervisor
    manager
    superadmin
    driver
    api
    universal
    engraver
  ].freeze

  ROLES_FOR_ADMIN = %w[
    admin
    software
    media
    technician
    marketing
    supervisor
    manager
    driver
    universal
    engraver
  ].freeze

  HELPABLE = %w[software media technician universal].freeze

  # Keep order!
  ABILITIES = %w[
    manage_wiki
    manage_salary
    print_receipt
    manage_timesheet
    manage_schedule
    edit_clients
    view_feedback_notifications
    edit_tasks_user_comment
    view_repair_parts
    comment_users
    see_stale_service_jobs
    manage_trade_in
    inventory
    view_reports
    view_feedbacks_in_city
    manage_stocks
    edit_price_in_sale
    view_quick_orders_and_free_jobs_everywhere
    move_transfers
    see_all_users
    access_all_departments
  ].freeze

  ACTIVITIES = %w[free fast long].freeze
  UNIFORM_SEX = %w[мужская женская].freeze
  UNIFORM_SIZE = %w[XS S M L XL XXL XXXL].freeze

  scope :in_department, ->(department) { where(department_id: department) }
  scope :in_city, ->(city) { where department_id: Department.in_city(city) }
  scope :located_at, ->(location) { where location_id: location }
  scope :id_asc, -> { order('id asc') }
  scope :ordered, -> { order('position asc') }
  scope :any_admin, -> { where(role: %w[admin superadmin]) }
  scope :superadmins, -> { where(role: 'superadmin') }
  scope :software, -> { where(role: 'software') }
  scope :media, -> { where(role: 'media') }
  scope :technician, -> { where(role: 'technician') }
  scope :not_technician, -> { where('role <> ?', 'technician') }
  scope :marketing, -> { where(role: 'marketing') }
  scope :programmer, -> { where(role: 'programmer') }
  scope :supervisor, -> { where(role: 'supervisor') }
  scope :manager, -> { where(role: 'manager') }
  scope :working_at, lambda { |day|
                       joins(:schedule_days).where('schedule_days.day = ? AND LENGTH(schedule_days.hours) > 0', day)
                     }
  scope :with_active_birthdays, -> { joins(:announcements).where(announcements: { kind: 'birthday', active: true }) }
  scope :with_inactive_birthdays, -> { joins(:announcements).where(announcements: { kind: 'birthday', active: false }) }
  scope :schedulable, -> { where(schedule: true) }
  scope :staff, -> { where.not(role: 'api') }
  scope :fired, -> { where(is_fired: true) }
  scope :active, -> { where(is_fired: [false, nil]) }
  scope :for_changing, -> { all }
  # scope :for_changing, where('users.username = ? OR users.username LIKE ?', 'vova', 'test_%')
  scope :exclude, ->(user) { where('id <> ?', user.is_a?(User) ? user.id : user) }
  # scope :upcoming_salary, where('hiring_date IN ?', [Date.current..Date.current.advance(days: 2)])
  scope :helps_in_repair, lambda {
                            where('users.is_fired != ? AND (users.can_help_in_repair = ? OR users.role = ?)',
                                  true, true, 'technician')
                          }

  scope :helps_in_mac_service, -> { active.where(can_help_in_mac_service: true) }

  belongs_to :location
  belongs_to :department
  has_many :history_records, as: :object, dependent: :nullify
  has_many :schedule_days, dependent: :destroy
  has_many :duty_days, dependent: :destroy
  has_many :orders, as: :customer, dependent: :nullify
  has_many :announcements, inverse_of: :user, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :service_jobs, -> { includes(:client, :features, department: :city, item: { product: :product_group }) }, inverse_of: :user
  has_many :karmas, dependent: :destroy, inverse_of: :user
  has_many :karma_groups, through: :karmas
  has_many :bonuses, through: :karma_groups
  has_many :messages, dependent: :destroy
  has_many :infos, inverse_of: :recipient, dependent: :destroy
  has_many :salaries, inverse_of: :user, dependent: :destroy
  has_many :timesheet_days, inverse_of: :user, dependent: :destroy
  has_and_belongs_to_many :addressed_announcements, class_name: 'Announcement', join_table: 'announcements_users',
                                                    uniq: true
  has_many :installment_plans, inverse_of: :user, dependent: :destroy
  has_many :sales, inverse_of: :user, dependent: :nullify
  has_many :movement_acts, dependent: :nullify
  has_many :stores, through: :department
  has_many :locations, through: :department
  has_many :device_notes, dependent: :destroy
  has_many :favorite_links, foreign_key: 'owner_id', dependent: :destroy
  has_many :faults, foreign_key: :causer_id, dependent: :destroy
  has_many :quick_orders
  has_many :service_free_jobs, -> { includes(:client) }, :class_name => 'Service::FreeJob', foreign_key: :receiver_id

  attr_accessor :login, :auth_token

  cattr_accessor :current

  accepts_nested_attributes_for :schedule_days, :duty_days, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :karmas, allow_destroy: true
  accepts_nested_attributes_for :salaries, reject_if: ->(attrs) { attrs['amount'].blank? or attrs['issued_at'].blank? }
  accepts_nested_attributes_for :installment_plans, reject_if: lambda { |attrs|
                                                                 (attrs['object'].blank? or attrs['cost'].blank? or attrs['issued_at'].blank?) and attrs['installments_attributes'].blank?
                                                               }

  delegate :city, :city_id, to: :department, allow_nil: true
  delegate :name, to: :department, prefix: true, allow_nil: true
  delegate :name, to: :location, prefix: true, allow_nil: true
  delegate :time_zone, to: :city, allow_nil: true

  # Setup accessible (or protected) attributes for your model
  attr_accessible :auth_token, :login, :username, :email, :role, :password, :password_confirmation,
                  :remember_me, :location_id, :surname, :name, :patronymic, :position, :birthday,
                  :hiring_date, :salary_date, :prepayment, :wish, :photo, :remove_photo, :photo_cache,
                  :schedule_days_attributes, :duty_days_attributes, :card_number, :color, :karmas_attributes,
                  :abilities, :activities, :schedule, :is_fired, :job_title, :position, :salaries_attributes,
                  :installment_plans_attributes, :installment, :department_id, :session_duration,
                  :phone_number, :department_autochangeable, :can_help_in_repair, :uniform_sex, :uniform_size,
                  :hobby, :wishlist, :can_help_in_mac_service

  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable, :registerable, :rememberable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :timeoutable, :recoverable, :trackable, :validatable

  validates_presence_of :username, :role, :department
  validates_uniqueness_of :username
  validates :password, presence: true, confirmation: true, if: :password_required?
  validates :role, inclusion: { in: ROLES }
  validates_numericality_of :session_duration, only_integer: true, greater_than: 0, allow_nil: true
  before_validation :validate_rights_changing
  # before_save :ensure_authentication_token

  mount_uploader :photo, PhotoUploader

  acts_as_list

  def self.find_first_by_auth_conditions(warden_conditions)
    conditions = warden_conditions.dup
    if auth_token = conditions.delete(:auth_token)
      User.active.where(conditions).where(['lower(username) = :value OR lower(card_number) = :value',
                                           { value: auth_token.mb_chars.downcase.to_s }]).first
    else
      User.active.where(conditions).first
    end
  end

  def self.search(params)
    users = params[:all].present? ? User.all : User.active
    unless (q_name = params[:name]).blank?
      users = users.where 'username LIKE :q or name LIKE :q or surname LIKE :q', q: "%#{q_name}%"
    end
    users
  end

  def self.oncoming_salary
    User.active.to_a.keep_if { |user| user.upcoming_salary_date&.today? }
  end

  def self.check_birthdays
    User.active.find_each do |user|
      announcement = user.birthday_announcement
      announcement.update_attributes active: user.upcoming_birthday?
      if announcement.active?
        announcement.recipient_ids = User.any_admin.map(&:id)
        announcement.save
      end
    end
  end

  def email_required?
    false
  end

  def superadmin?
    has_role? 'superadmin'
  end

  def admin?
    has_role? 'admin'
  end

  def any_admin?
    has_role? %w[admin superadmin]
  end

  def not_admin?
    !admin? and !superadmin?
  end

  def technician?
    has_role? 'technician'
  end

  def software?
    has_role? %w[software universal]
  end

  def media?
    has_role? %w[media universal]
  end

  def marketing?
    has_role? 'marketing'
  end

  def developer?
    has_role? 'developer'
  end

  def supervisor?
    has_role? 'supervisor'
  end

  def manager?
    has_role? 'manager'
  end

  def driver?
    role == 'driver'
  end

  def api?
    role == 'api'
  end

  def universal?
    role == 'universal'
  end

  def has_role?(role)
    if role.is_a? Array
      role.include? self.role
    else
      self.role == role
    end
  end

  def role_match?(other_role)
    (role == other_role) ||
      (universal? && other_role.in?(%w[media software]))
  end

  def code_match?(code)
    technician? && code == 'repairmac'
  end

  def full_name
    res = [surname, name, patronymic].join ' '
    res = username if res.blank?
    res
  end

  def fio_short
    res = surname
    res += " #{name[0]}." unless name.blank?
    res += " #{patronymic[0]}." unless patronymic.blank?
    res
  end

  def short_name
    res = [name, surname].join ' '
    res = username if res.blank?
    res
  end

  def presentation
    short_name
  end

  def is_duty_day?(date)
    duty_days.exists? day: date
  end

  def is_duty_today?
    duty_days.exists? day: Date.current
  end

  def is_work_day?(day)
    day = day.respond_to?(:wday) ? day.wday : day.to_i
    if (schedule_day = schedule_days.find_by_day(day)).present?
      schedule_day.hours.present?
    else
      false
    end
  end

  def begin_of_work(day)
    schedule_days.find_by_day(day.wday).try(:begin_of_work)
  end

  def is_shortened_day?(date)
    if is_work_day? date
      hours = schedule_days.find_by_day(date.wday).hours.split(',').map(&:to_i).sort
      hours[-1] < 20
    else
      false
    end
  end

  def announced?
    case role
    when 'software'
      announcements.active_help.any?
    when 'media'
      announcements.active_coffee.any?
    when 'technician'
      announcements.active_protector.any?
    else
      false
    end
  end

  def announced_birthday?
    announcements.active_birthdays.any?
  end

  def helpable?
    User::HELPABLE.include? role
  end

  def color_s
    color.blank? ? '#ffffff' : color
  end

  def upcoming_birthday?
    if birthday.present?
      today = Date.current
      date = birthday.change(year: today.year)
      date = date.next_year if date < today
      date.between? today, 3.days.from_now.end_of_day.to_datetime
    else
      false
    end
  end

  def birthday_announcement
    announcements.create_with(active: false, user: self).find_or_create_by(kind: 'birthday')
  end

  def timeout_in
    if session_duration.present?
      session_duration.minutes
    else
      30.minutes
    end
  end

  def abilities=(abilities)
    self.abilities_mask = (abilities & ABILITIES).map { |a| 2**ABILITIES.index(a) }.inject(0, :+)
  end

  def abilities
    ABILITIES.reject { |a| ((abilities_mask || 0) & 2**ABILITIES.index(a)).zero? }
  end

  def able_to?(ability)
    abilities.include? ability.to_s
  end

  def activities=(activities)
    self.activities_mask = (activities & ACTIVITIES).map { |a| 2**ACTIVITIES.index(a) }.inject(0, :+)
  end

  def activities
    ACTIVITIES.reject { |a| ((activities_mask || 0) & 2**ACTIVITIES.index(a)).zero? }
  end

  def acts_to?(activity)
    activities.include? activity.to_s
  end

  def able_to_move_transfers?
    superadmin? || able_to?(:move_transfers)
  end

  def rating
    good_count = karmas.good.count
    bad_count = karmas.bad.count
    good_count.positive? || bad_count.positive? ? (good_count - bad_count) : 0
  end

  def upcoming_salary_date
    return unless hiring_date.present?

    today = Date.current
    date = if today.end_of_month.day < hiring_date.day
             hiring_date.change(day: today.end_of_month.day,
                                month: today.month, year: today.year)
           else
             hiring_date.change(
               month: today.month, year: today.year
             )
           end
    date < today ? date.next_month : date
  end

  def salary_date_at(date)
    if hiring_date.present?
      if date.end_of_month.day < hiring_date.day
        hiring_date.change(day: date.end_of_month.day, month: date.month, year: date.year)
      else
        hiring_date.change(month: date.month, year: date.year)
      end
    end
  end

  def work_days_in(date)
    timesheet_days.in_period(date).work.count
  end

  def work_hours_in(date)
    timesheet_days.in_period(date).work.to_a.sum(&:actual_work_hours)
  end

  def sickness_days_in(date)
    timesheet_days.in_period(date).sickness.count
  end

  def latenesses_in(date)
    timesheet_days.in_period(date).lateness.count
  end

  def installment=(params)
    if params[:installment_plan_id].present? && params[:value].present? && params[:paid_at].present? && (installment_plan = installment_plans.find(params[:installment_plan_id])).present?
      installment_plan.installments.create value: params[:value], paid_at: params[:paid_at]
    end
  end

  def installments
    Installment.where installment_plan_id: installment_plan_ids
  end

  def timesheet_day(date)
    timesheet_days.find_by_date(date)
  end

  def archive_location
    locations.archive.first
  end

  def done_locations
    locations.where(code: 'done')
  end

  def done_location
    min_term = done_locations.minimum(:storage_term)
    done_locations.where(storage_term: min_term).first
  end

  def retail_store
    stores.retail.first
  end

  def spare_parts_store
    stores.spare_parts.first
  end

  def defect_store
    stores.defect.first
  end

  def defect_sp_store
    stores.defect_sp.first
  end

  def default_store
    technician? ? spare_parts_store : retail_store
  end

  def cash_drawer
    department.cash_drawers.first
  end

  def current_cash_shift
    cash_drawer.current_shift
  end

  def faults_info(date)
    faults_on_date = faults.where('date <= ?', date)
    counts_on_date = faults_on_date.group(:kind_id).count
    start_date = date.beginning_of_month
    faults_in_month = faults.where(date: start_date..date)
    counts_in_month = faults_in_month.group(:kind_id).count

    result = {}

    counts_on_date.each do |id, count|
      month_count = counts_in_month.fetch(id, 0)
      fault_kind = FaultKind.find(id)
      penalty_sum = faults_on_date.where(kind: fault_kind).sum(:penalty)
      result.store fault_kind, { month: month_count, total: count, penalty_sum: penalty_sum }
    end

    result
  end

  def period
    Date.today.at_beginning_of_month.to_time(:local).beginning_of_day..Date.today.to_time(:local).end_of_day
  end

  def free_jobs_count
    Service::FreeJob.joins(:receiver, :task)
                    .where(performed_at: period, receiver_id: id)
                    .count
  end

  def fast_jobs_count
    QuickOrder.includes(:user)
              .where(created_at: period, user_id: id)
              .count
  end

  def long_jobs_count
    service_jobs.where('created_at > ?', Date.today.at_beginning_of_month.to_time(:local)).count
  end

  private

  def validate_rights_changing
    if (changed_attributes[:role].present? || changed_attributes[:abilities].present?) && !User.current.superadmin?
      errors[:base] << 'Rights changing denied!'
    end
  end

  def ensure_an_admin_remains
    errors[:base] << I18n.t('users.deny_destroing') and return false if User.superadmins.count == 1
  end

  def password_required?
    new_record?
  end
end
