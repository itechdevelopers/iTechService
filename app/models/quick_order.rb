# frozen_string_literal: true

class QuickOrder < ApplicationRecord
  include Auditable

  DEVICE_KINDS = %w[iPhone iPad iPod Storage].freeze

  scope :in_department, ->(department) { where department_id: department }
  scope :id_asc, -> { order('quick_orders.id asc') }
  scope :created_desc, -> { order('quick_orders.created_at desc') }
  scope :in_month, -> { where('quick_orders.created_at > ?', 1.month.ago) }
  scope :done, -> { where(is_done: true) }
  scope :undone, -> { where(is_done: false) }

  belongs_to :department
  belongs_to :user
  belongs_to :client
  has_and_belongs_to_many :quick_tasks, join_table: 'quick_orders_quick_tasks'
  has_many :history_records, as: :object, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy
  validates_presence_of :security_code, :device_kind
  validates :quick_tasks, presence: { message: "Должна быть отмечена хотя бы одна быстрая задача." }

  delegate :short_name, to: :user, prefix: true, allow_nil: true
  delegate :name, to: :department, prefix: true, allow_nil: true

  after_initialize do
    self.department_id ||= Department.current.id
    self.user_id ||= User.current.try(:id)
    self.is_done ||= false
  end

  before_create :set_number

  audited
  has_associated_audits

  def self.search(params)
    quick_orders = QuickOrder.all

    if (is_done = params[:done]).present?
      quick_orders = quick_orders.where is_done: is_done
    end

    if (number = params[:number]).present?
      quick_orders = quick_orders.where number: number
    end

    if (client_name = params[:client_name]).present?
      quick_orders = quick_orders.includes(:client).where(
        'LOWER(quick_orders.client_name) LIKE :q OR LOWER(clients.name) LIKE :q OR LOWER(clients.surname) LIKE :q', q: "%#{client_name.mb_chars.downcase}%"
      ).references(:clients)
    end

    if (contact_phone = params[:contact_phone]).present?
      quick_orders = quick_orders.includes(:client).where(
        'quick_orders.contact_phone LIKE :q OR clients.phone_number LIKE :q OR clients.full_phone_number LIKE :q', q: "%#{contact_phone}%"
      ).references(:clients)
    end

    if (task = params[:task]).present?
      quick_orders = quick_orders.includes(:quick_tasks).where('LOWER(quick_tasks.name) LIKE ?',
                                                               "%#{task.mb_chars.downcase}%")
    end

    quick_orders
  end

  def set_done
    update_attributes is_done: true
  end

  def number_s
    format('%04d', number)
  end

  def client_presentation
    if client_id.nil?
      [client_name, contact_phone].compact.join(' / ')
    else
      client.presentation
    end
  end

  def client_short_name
    client&.short_name || client_name
  end

  def client_phone
    client&.human_phone_number || contact_phone
  end

  def url
    Rails.application.routes.url_helpers.quick_order_path(self)
  end

  private

  def set_number
    last_number = QuickOrder.created_desc.first.try(:number)
    self.number = last_number.present? && (last_number < 9999) ? last_number.next : 1
  end
end
