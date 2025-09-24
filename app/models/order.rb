# frozen_string_literal: true

class Order < ApplicationRecord
  include Auditable

  OBJECT_KINDS = %w[device accessory soft misc spare_part].freeze
  STATUSES = %w[new pending current on_the_way done canceled notified issued archive].freeze
  OLD_STATUSES = %w[new pending done canceled notified issued archive].freeze
  NEW_STATUSES = %w[current on_the_way done notified archive].freeze
  ARCHIVE_REASONS = %w[order_picked_up order_cancelled_by_customer order_cancelled_by_company order_created_by_mistake].freeze

  scope :in_department, ->(department) { where department_id: department }
  scope :newest, -> { order('orders.created_at desc') }
  scope :oldest, -> { order('orders.created_at asc') }
  scope :new_orders, -> { where(status: 'new') }
  scope :pending_orders, -> { where(status: 'pending') }
  scope :done_orders, -> { where(status: 'done') }
  scope :canceled_orders, -> { where(status: 'canceled') }
  scope :notified_orders, -> { where(status: 'notified') }
  scope :archive_orders, -> { where(status: 'archive') }
  scope :actual_orders, -> { where(status: %w[current on_the_way new pending notified done]) }
  scope :technician_orders, -> { where(object_kind: 'spare_part') }
  scope :marketing_orders, -> { where('object_kind <> ?', 'spare_part') }
  scope :device, -> { where(object_kind: 'device') }
  scope :accessory, -> { where(object_kind: 'accessory') }
  scope :soft, -> { where(object_kind: 'soft') }
  scope :misc, -> { where(object_kind: 'misc') }
  scope :spare_part, -> { where(object_kind: 'spare_part') }
  scope :done_at, lambda { |period|
                    joins(:history_records).where(history_records: { column_name: 'status', new_value: 'done', created_at: period })
                  }

  belongs_to :department
  belongs_to :customer, polymorphic: true, optional: true
  belongs_to :source_store, class_name: 'Store', optional: true
  belongs_to :source_department, class_name: 'Department', optional: true
  belongs_to :user, optional: true
  has_many :history_records, as: :object
  has_many :notes, class_name: 'OrderNote', dependent: :destroy
  has_many :external_syncs, class_name: 'OrderExternalSync', dependent: :destroy
  has_one :one_c_sync, -> { where(external_system: :one_c) }, class_name: 'OrderExternalSync'

  enum payment_method: %i[card cash credit gift_certificate]

  mount_uploader :picture, OrderPictureUploader

  delegate :name, to: :department, prefix: true, allow_nil: true
  validates :customer, :department, :quantity, :object, :object_kind, presence: true
  validates :priority, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10 }
  validates :archive_reason, inclusion: { in: ARCHIVE_REASONS }, allow_nil: true
  after_initialize :set_department
  before_validation :generate_number, :preprocess_article

  before_validation do |order|
    if order.new_record?
      if order.customer_id.blank?
        order.customer_id = User.current.id
        order.customer_type = 'User'
      else
        order.customer_type = 'Client'
      end
      order.user_id ||= User.current.id
    end
  end

  after_update :make_announcement, :clear_attention_if_article_added
  after_update_commit :trigger_one_c_deletion_on_archive, :trigger_one_c_status_update
  # Note: :check_for_sync_update removed to disable automatic 1C sync on order updates
  # Manual sync is still available via the UI button

  audited
  has_associated_audits

  def self.order_by_status
    ret = 'CASE'
    STATUSES.each_with_index do |s, i|
      ret << " WHEN status = '#{s}' THEN #{i}"
    end
    ret << ' END'
  end

  scope :by_status, -> { order order_by_status }

  def archive_reason=(value)
    super(value.presence)
  end

  def customer_full_name
    customer.try :full_name
  end

  def customer_short_name
    customer.try :short_name
  end

  def customer_presentation
    customer.try :presentation
  end

  def client
    customer
  end

  def client_id
    customer_id
  end

  def done?
    status == 'done'
  end

  def canceled?
    status == 'canceled'
  end

  def archived?
    status == 'archive'
  end

  def done_at
    history_records.where({ column_name: 'status', new_value: 'done' }).last.try :created_at
  end

  def self.search(params)
    orders = Order.all

    orders = if (statuses = params[:statuses] || [] & STATUSES).any?
               orders.where status: statuses
             else
               orders.actual_orders
             end

    if (object_kind_q = params[:object_kind]).present? && (OBJECT_KINDS.include? object_kind_q)
      orders = orders.send object_kind_q
    end

    if (number_q = params[:order_number]).present?
      orders = orders.where 'number LIKE :q', q: "%#{number_q}%"
    end

    if (object_q = params[:object]).present?
      orders = orders.where 'LOWER(object) LIKE :q', q: "%#{object_q.mb_chars.downcase}%"
    end

    if (customer_q = params[:customer]).present?
      client_ids = Client.where(
        'LOWER(clients.surname) LIKE :q OR LOWER(clients.name) LIKE :q OR LOWER(clients.patronymic) LIKE :q OR clients.phone_number LIKE :q OR clients.full_phone_number LIKE :q OR LOWER(clients.card_number) LIKE :q',
        q: "%#{customer_q.mb_chars.downcase}%"
      ).map(&:id)
      user_ids = User.where('LOWER(name) LIKE :q OR LOWER(surname) LIKE :q OR LOWER(username) LIKE :q',
                            q: "%#{customer_q.mb_chars.downcase}%").select(:id).map(&:id)
      orders = orders.where(
        '(customer_type = ? AND customer_id IN (?)) OR (customer_type = ? AND customer_id IN (?))',
        'Client', client_ids, 'User', user_ids
      )
    end

    if (user_q = params[:user]).present?
      orders = orders.joins(:user).where(
        'LOWER(users.name) LIKE :q OR LOWER(users.surname) LIKE :q OR LOWER(users.username) LIKE :q OR LOWER(users.card_number) LIKE :q',
        q: "%#{user_q.mb_chars.downcase}%"
      )
    end

    if params[:article].present?
      article_q = params[:article]
      product_name = Product.find_by(article: article_q)&.name
      
      # Проверяем, был ли найден продукт
      if product_name.present?
        orders = orders.where(
          'object LIKE :q OR article = :article_q',
          q: "%#{product_name}%",
          article_q: article_q
        )
      else
        # Если продукт не найден, ищем только по артикулу
        orders = orders.where(article: article_q)
      end
    end

    unless (department_ids = params[:department_ids]).blank?
      orders = orders.where(department_id: department_ids)
    end

    orders
  end

  def status_for_client
    status == 'done' ? 'done' : 'undone'
  end

  def status_info
    {
      status: status == 'done' ? 'done' : 'undone'
    }
  end

  def generate_number
    if number.blank?
      num = nil
      loop do
        num = UUIDTools::UUID.random_create.hash.to_s
        break unless Order.exists?(number: num)
      end
      self.number = num
    end
  end

  def article_requires_attention?
    device_order? && (article.blank? || article.strip.blank?)
  end

  def device_order?
    object_kind == 'device'
  end

  # Helper method to create or update 1C sync record
  def ensure_one_c_sync_record!
    one_c_sync || external_syncs.create!(
      external_system: :one_c,
      sync_status: :pending,
      attention_required: device_order? && (article.blank? || article.strip.blank?)
    )
  end

  private

  def make_announcement
    if !changed_attributes[:status].present? && (announcement = create_announcement).present?
      AnnouncementRelayJob.perform_later(announcement.id)
    end
  end

  def create_announcement
    kind = done? ? 'order_done' : 'order_status'
    content = "#{I18n.t('orders.order_num', num: number)} #{I18n.t("orders.statuses.#{status}")}"
    Announcement.create user_id: user_id, kind: kind, active: true, content: content
  end

  def set_department
    self.department_id ||= if User.current.user_settings.auto_department_detection?
      Department.current.id
    else
      nil
    end
  end

  def preprocess_article
    return unless article.present?
    self.article = article.strip.squish
  end

  def clear_attention_if_article_added
    return unless saved_change_to_article?
    return unless one_c_sync&.attention_required?
    
    # Clear attention flag only if article is present AND sync is successful
    # If sync failed, attention is still needed for sync failure
    if article.present? && !article_requires_attention? && one_c_sync.synced?
      one_c_sync.update!(attention_required: false)
    end
  end

  def check_for_sync_update
    return unless one_c_synced?
    
    # Define fields that require 1C update when changed
    significant_changes = %w[article object quantity approximate_price comment]
    
    # Check if any significant fields were changed
    if (changed & significant_changes).any?
      Rails.logger.info "[OrderUpdate] Order #{id} has significant changes, triggering 1C update"
      OneCOrderUpdateJob.perform_later(id, User.current&.id)
    end
  end

  # 1C sync convenience methods (replacing one_c_synced methods)
  def one_c_synced?
    one_c_sync&.synced? || false
  end

  def one_c_sync_status
    one_c_sync&.sync_status || 'not_synced'
  end

  def one_c_external_id
    one_c_sync&.external_id
  end

  def one_c_last_error
    one_c_sync&.last_error
  end

  def one_c_sync_attempts
    one_c_sync&.sync_attempts || 0
  end

  def one_c_last_attempt_at
    one_c_sync&.last_attempt_at
  end

  def requires_one_c_sync?
    one_c_sync.nil? || one_c_sync.failed? || one_c_sync.pending?
  end

  def can_retry_one_c_sync?
    # Note: Retry logic now handled by ActiveJob, this method kept for compatibility
    one_c_sync&.pending? || one_c_sync&.failed?
  end

  def requires_article_attention?
    one_c_sync&.requires_article_attention? || false
  end

  def trigger_one_c_deletion_on_archive
    # Only trigger if status changed to archive
    if saved_change_to_status? && status == 'archive'
      # Only delete if order was synced to 1C
      if one_c_sync&.synced? && one_c_sync.external_id.present?
        Rails.logger.info "[Order] Automatically triggering 1C deletion for archived order #{id}"
        OneCOrderDeleteJob.perform_later(id, nil) # nil user_id = no notifications
      else
        Rails.logger.info "[Order] Order #{id} archived but not synced to 1C, skipping deletion"
      end
    end
  end

  def trigger_one_c_status_update
    # Only trigger if status changed and order is synced
    if saved_change_to_status? && one_c_synced?
      Rails.logger.info "[Order] Triggering 1C status update for order #{id}"
      OneCOrderStatusUpdateJob.perform_later(id, nil)
    end
  end
end
