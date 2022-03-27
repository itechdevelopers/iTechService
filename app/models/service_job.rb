
class ServiceJob < ApplicationRecord
  scope :in_department, ->(department) { located_at(Location.in_department(department)) }
  scope :order_by_product_name, -> { includes(item: :product).order('products.name') }
  scope :received_at, ->(period) { where created_at: period }
  scope :newest, -> { order('service_jobs.created_at desc') }
  scope :oldest, -> { order('service_jobs.created_at asc') }
  scope :done, -> { where('service_jobs.done_at IS NOT NULL').order('service_jobs.done_at desc') }
  scope :pending, -> { where(done_at: nil) }
  scope :important, -> { includes(:tasks).where('tasks.priority > ?', Task::IMPORTANCE_BOUND) }
  scope :replaced, -> { where(replaced: true) }
  scope :located_at, ->(location) { where(location_id: location) }

  scope :ready, lambda { |department = nil|
    locations = Location.done.short_term
    locations = locations.in_department(department) if department
    where location_id: locations
  }

  scope :at_done, lambda { |department = nil|
    locations = department ? Location.in_department(department).done : Location.done
    where(location_id: locations)
  }

  scope :at_archive, lambda { |department = nil|
    locations = department ? Location.in_department(department).archive : Location.archive
    where(location_id: locations)
  }

  scope :not_at_done, -> { where.not(location: Location.done) }
  scope :not_at_archive, -> { where.not(location_id: Location.archive) }

  scope :for_returning, lambda {
    not_at_done.not_at_archive.where('((return_at - created_at) > ? and (return_at - created_at) < ? and return_at <= ?) or ((return_at - created_at) >= ? and return_at <= ?)', '30 min', '5 hour', DateTime.current.advance(minutes: 30), '5 hour', DateTime.current.advance(hours: 1))
  }

  scope :of_product_group, ->(product_group_id) {
    joins(item: :product).where(products: {product_group_id: ProductGroup.children_of(product_group_id)})
  }

  belongs_to :department, -> { includes(:city) }, inverse_of: :service_jobs
  belongs_to :initial_department, class_name: 'Department', optional: true
  belongs_to :user, inverse_of: :service_jobs, optional: true
  belongs_to :client, inverse_of: :service_jobs, optional: true
  belongs_to :device_type, optional: true
  belongs_to :item, -> { includes(:features, product: %i[product_group product_category]) }, optional: true
  belongs_to :location, optional: true
  belongs_to :receiver, class_name: 'User', foreign_key: 'user_id', optional: true
  belongs_to :sale, inverse_of: :service_job, optional: true
  belongs_to :case_color, optional: true
  belongs_to :carrier, optional: true
  belongs_to :keeper, class_name: 'User', optional: true
  has_many :features, through: :item
  has_many :device_tasks, dependent: :destroy
  has_many :tasks, through: :device_tasks
  has_many :repair_tasks, through: :device_tasks
  has_many :repair_parts, through: :repair_tasks
  has_many :history_records, as: :object, dependent: :destroy
  has_many :device_notes, dependent: :destroy
  has_many :feedbacks, class_name: Service::Feedback.name, dependent: :destroy
  has_many :inactive_feedbacks, -> { inactive }, class_name: Service::Feedback.name, dependent: :destroy
  has_one :substitute_phone, dependent: :nullify
  has_many :viewings, class_name: ServiceJobViewing.name, dependent: :destroy
  has_one :review

  has_and_belongs_to_many :subscribers,
                          join_table: :service_job_subscriptions,
                          association_foreign_key: :subscriber_id,
                          class_name: 'User',
                          dependent: :destroy

  accepts_nested_attributes_for :device_tasks, allow_destroy: true

  delegate :name, :short_name, :full_name, :surname, to: :client, prefix: true, allow_nil: true
  delegate :name, to: :department, prefix: true
  delegate :name, to: :location, prefix: true, allow_nil: true
  delegate :city, :city_id, to: :department, allow_nil: true
  delegate :color, to: :city, prefix: true, allow_nil: true
  delegate :pending_substitution, to: :substitute_phone, allow_nil: true
  alias_attribute :received_at, :created_at
  validates_presence_of :ticket_number, :user, :client, :location, :device_tasks, :return_at, :department
  validates_presence_of :contact_phone, on: :create
  validates_presence_of :device_type, if: proc { |sj| sj.item.nil? }
  validates_presence_of :item, if: proc { |sj| sj.device_type.nil? }
  validates_presence_of :app_store_pass, if: :new_record?
  validates_uniqueness_of :ticket_number
  validates_inclusion_of :is_tray_present, in: [true, false], if: :has_imei?
  validates :substitute_phone_icloud_connected, presence: true, acceptance: true, on: :create, if: :phone_substituted?
  validate :presence_of_payment
  validate :substitute_phone_absence

  after_initialize :set_user_and_location
  after_initialize :set_contact_phone
  before_validation :generate_ticket_number
  before_validation :validate_security_code
  before_validation :set_user_and_location
  before_validation :validate_location
  after_validation :set_department
  after_save :update_qty_replaced
  after_save :update_tasks_cost
  after_create :new_service_job_announce
  after_create :create_alert
  after_update :service_job_update_announce
  after_update :deduct_spare_parts

  def self.search(params)
    service_jobs = ServiceJob.includes :device_tasks, :tasks

    unless (status_q = params[:status]).blank?
      service_jobs = service_jobs.send status_q if %w[done pending important].include? status_q
    end

    unless params[:location_id].blank?
      service_jobs = service_jobs.where service_jobs: params.slice(:location_id)
    end

    unless (ticket_q = params[:ticket]).blank?
      service_jobs = service_jobs.where 'service_jobs.ticket_number LIKE ?', "%#{ticket_q}%"
    end

    unless (service_job_q = (params[:service_job] || params[:service_job_q])).blank?
      service_jobs = service_jobs.includes(:features).where('LOWER(features.value) LIKE :q OR LOWER(service_jobs.serial_number) LIKE :q OR LOWER(service_jobs.imei) LIKE :q', q: "%#{service_job_q.mb_chars.downcase.to_s}%").references(:features)
    end

    unless (client_q = params[:client]).blank?
      service_jobs = service_jobs.joins(:client).where 'LOWER(clients.name) LIKE :q OR LOWER(clients.surname) LIKE :q OR clients.phone_number LIKE :q OR clients.full_phone_number LIKE :q OR LOWER(clients.card_number) LIKE :q', q: "%#{client_q.mb_chars.downcase.to_s}%"
    end

    service_jobs
  end

  def self.quick_search(query)
    service_jobs = ServiceJob.not_at_archive

    unless query.blank?
      service_jobs = service_jobs.joins(:client)
                                 .where('service_jobs.ticket_number LIKE :q OR service_jobs.contact_phone LIKE :q OR LOWER(clients.name) LIKE :q OR LOWER(clients.surname) LIKE :q',
                                        q: "%#{query.mb_chars.downcase.to_s}%")
    end

    service_jobs
  end

  def self.stale_at_done_over(term, department_id: nil)
    done_locations = Location.done
    done_locations = done_locations.in_department(department_id) unless department_id.nil?
    storage_locations = done_locations.where(storage_term: term)
    min_term = Location.done.minimum(:storage_term)
    done_location_ids = Location.done.where(storage_term: min_term).pluck(:id)

    jobs = includes(:history_records)
           .where(location: storage_locations, history_records: { column_name: 'location_id', new_value: done_location_ids })
           .where('history_records.created_at < ?', term.months.ago)
    jobs
  end

  def as_json(_options = {})
    {
      id: id,
      ticket_number: ticket_number,
      user_name: user_short_name,
      device_type: type_name,
      imei: imei,
      serial_number: serial_number,
      status: status,
      comment: comment,
      at_done: at_done?,
      in_archive: in_archive?,
      location: location&.name,
      client: {
        id: client_id,
        name: client&.short_name,
        phone: client&.phone_number
      },
      contact_phone: contact_phone,
      tasks: device_tasks,
      total_cost: tasks_cost,
      case_color: case_color.as_json(only: %i[name color])
    }
  end

  def type_name
    item.present? ? item.name : (device_type&.full_name || '-')
  end

  def device_short_name
    item&.product_group_name
  end

  def imei
    item&.imei || self['imei']
  end

  def serial_number
    item&.serial_number || self['serial_number']
  end

  def client_phone
    client.try(:phone_number) || '-'
  end

  def client_presentation
    client.try(:presentation) || '-'
  end

  def user_name
    (user || User.current).name
  end

  def user_short_name
    (user || User.current).short_name
  end

  def user_full_name
    (user || User.current).full_name
  end

  def presentation
    if item.present?
      sn = item.serial_number
      imei = item.imei
    else
      sn = serial_number.presence || '?'
      imei = self.imei.presence || '?'
    end
    [type_name, sn, imei].join(' / ')
  end

  def done?
    pending_tasks.empty?
  end

  def pending?
    !done?
  end

  def transferred?
    initial_department_id.present? && department_id != initial_department_id
  end

  def done_tasks
    device_tasks.done
  end

  def undone_tasks
    device_tasks.undone
  end

  def processed_tasks
    device_tasks.processed
  end

  def pending_tasks
    device_tasks.pending
  end

  def is_important?
    tasks.important.any?
  end

  def progress
    "#{processed_tasks.count} / #{device_tasks.count}"
  end

  def progress_pct
    (processed_tasks.count * 100.0 / device_tasks.count).to_i
  end

  def tasks_cost
    device_tasks.sum :cost
  end

  def status
    location.is_done? ? 'done' : 'undone'
  end

  def status_info
    {
      status: status
    }
  end

  def is_iphone?
    device_type.is_iphone? if device_type.present?
  end

  def has_imei?
    device_type.has_imei? if device_type.present?
  end

  def moved_at
    if (rec = history_records.movements.order_by_newest.first).present?
      rec.created_at
    end
  end

  def moved_by
    if (rec = history_records.movements.order_by_newest.first).present?
      rec.user
    end
  end

  def is_actual_for?(user)
    device_tasks.any? { |t| user.role_match?(t.role) }
  end

  def movement_history
    records = history_records.movements.order('created_at desc')
    records.map do |record|
      [record.created_at, record.new_value, record.user_id]
    end
  end

  def at_done?
    location.try(:is_done?)
    # reload.location.try(:is_done?)
  end

  def in_archive?
    location.try(:is_archive?)
  end

  def barcode_num
    '0' * (12 - ticket_number.length) + ticket_number
  end

  def service_duration=(duration)
    if duration.is_a? String
      array = duration.split '.'
      array.map!(&:to_i)
      now = DateTime.current.change sec: 0
      self.return_at = now.advance minutes: array[-1], hours: array[-2], days: array[-3]
    end
  end

  def returning_alert
    if location.is_repair?
      recipient_ids = User.active.map(&:id)
    else
      recipient_ids = User.active.not_technician.map(&:id)
    end
    announcement = Announcement.create_with(active: true, recipient_ids: recipient_ids).find_or_create_by(
kind: 'device_return', content: id.to_s)
    PrivatePub.publish_to '/service_jobs/returning_alert', announcement_id: announcement.id
  end

  def create_filled_sale
    sale_attributes = { client_id: client_id, store_id: User.current.retail_store.id, sale_items_attributes: {} }
    device_tasks.paid.each_with_index do |device_task, index|
      sale_item_attributes = { device_task_id: device_task.id, item_id: device_task.task&.product&.items&.first&.id,
price: device_task.cost.to_f, quantity: 1 }
      sale_attributes[:sale_items_attributes].store index.to_s, sale_item_attributes
      # new_sale.sale_items.build item_id: device_task.item.id, price: device_task.cost, quantity: 1
    end
    new_sale = create_sale sale_attributes
    update_attribute :sale_id, new_sale.id
    new_sale
  end

  def archive
    update location_id: department.locations.archive.first.id
  end

  def contact_phone_none?
    contact_phone.blank? or contact_phone == '-'
  end

  def data_storages
    self[:data_storages]&.split(',') || []
  end

  def data_storages=(new_value)
    if new_value.respond_to? :join
      super new_value.join(',')
    else
      super
    end
  end

  def note
    device_notes.last&.content&.presence || comment
  end

  def substitute_phone_id
    substitute_phone&.id
  end

  def substitute_phone_id=(new_id)
    if new_id.present?
      new_substitute_phone = SubstitutePhone.find new_id
      self.substitute_phone = new_substitute_phone if new_substitute_phone.service_job_id.nil?
    else
      self.substitute_phone = nil
    end
  end

  def phone_substituted?
    substitute_phone.present?
  end

  def work_order_filled?
    device_condition.present?
  end

  # TODO: correct
  def archived_at
    return unless in_archive?

    moved_at
  end

  private

  def generate_ticket_number
    if ticket_number.blank?
      number = nil
      loop do
        number = UUIDTools::UUID.random_create.hash.to_s
      break unless ServiceJob.exists? ticket_number: number
      end
      self.ticket_number = Setting.ticket_prefix(department) + number
    end
  end

  def update_qty_replaced
    if changed_attributes[:replaced].present? && (replaced != changed_attributes[:replaced])
      qty_replaced = ServiceJob.replaced.where(device_type_id: device_type_id)
      device_type.update_attribute :qty_replaced, qty_replaced
    end
  end

  def update_tasks_cost
    if location_id_changed? && location.is_done? && repair_tasks.present?
      repair_tasks.each do |repair_task|
        if repair_task.device_task.cost.zero?
          repair_task.device_task.update_attribute(:cost, repair_task.device_task.repair_cost)
        end
      end
    end
  end

  def validate_security_code
    if is_iphone? && security_code.blank?
      errors.add :security_code, I18n.t('.errors.messages.empty')
    end
  end

  def set_user_and_location
    self.user_id ||= User&.current&.id
    self.location_id ||= User&.current&.location_id
    self.department_id ||= Department.current&.id
  rescue StandardError
    nil
  end

  def validate_location
    old_location = location_id_changed? ? Location.find_by(id: location_id_was) : nil

    if location&.is_done? && pending?
      errors.add :location_id, I18n.t('service_jobs.errors.pending_tasks')
    end

    if location&.is_done? && notify_client? && client_notified.nil?
      errors.add :client_notified, I18n.t('service_jobs.errors.client_notification')
    end

    if location&.is_archive? && old_location && !old_location&.is_done?
      errors.add :location_id, 'Работа не в "Готово".'
    end

    if old_location.present?
      if (old_location&.is_archive? && User.current.not_admin?) ||
         (location.is_special? && User.current.not_admin?) ||
         (old_location&.is_special? && !User.current.superadmin?)
        errors.add :location_id, I18n.t('service_jobs.errors.not_allowed')
      end

      if (location.in_transfer? || old_location.in_transfer?) && !User.current.able_to_move_transfers?
        errors.add :location_id, 'Вы не можете перемещать трансферы'
      end
    end

    if location&.is_repair_notebooks? && old_location.present?
      MovementMailer.notice(id).deliver_later
    end

    # if User.current.not_admin? and old_location != User.current.location
    #  self.errors.add :location_id, I18n.t('service_jobs.movement_error_not_allowed')
    # end
  end

  def new_service_job_announce
    # PrivatePub.publish_to '/service_jobs/new', service_job: self if Rails.env.production?
  end

  def service_job_update_announce
    if changed_attributes['location_id'].present?
      if at_done?
        Announcement.find_by_kind_and_content('device_return', id.to_s).try(:destroy)
        ServiceJobsMailer.done_notice(id).deliver_later if email.present?
      end
    end
    # PrivatePub.publish_to '/service_jobs/update', service_job: self if changed_attributes['location_id'].present? and Rails.env.production?
  end

  def create_alert
    # service duration in minutes
    duration = (return_at.to_i - created_at.to_i) / 60
    if duration > 30
      alert_times = []
      alert_times.push return_at.advance minutes: -30 if duration < 300
      alert_times.push return_at.advance hours: -1 if duration >= 300
      alert_times.push return_at.advance days: -1 if duration > 1440
      # TODO: переделать
      # alert_times.each { |alert_time| self.delay(run_at: alert_time).returning_alert }
    end
  end

  def presence_of_payment
    return true unless location_id_changed? && location&.is_archive?
    return true unless tasks_cost.positive?
    return true unless sale.nil? || !sale.is_posted?

    errors.add :base, :not_paid
  end

  def substitute_phone_absence
    if location_id_changed? && location.is_archive?
      if substitute_phone.present?
        errors.add :base, :substitute_phone_not_received
      end
    end
  end

  def set_contact_phone
    self.contact_phone = client.try(:contact_phone) || '-' if contact_phone.blank?
  rescue StandardError
    nil
  end

  def set_department
    self.department_id = location&.department_id
  end

  def deduct_spare_parts
    if location_id_changed? && location.is_done?
      repair_parts.all?(&:deduct_spare_parts)
    end
  end
end
