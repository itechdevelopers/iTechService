# frozen_string_literal: true

class Client < ApplicationRecord
  include ApplicationHelper

  CATEGORIES = {
    0 => 'usual',
    1 => 'regular',
    2 => 'super',
    3 => 'friend'
  }.freeze

  RESTRICTED_ATTRIBUTES = %w[surname name patronymic birthday card_number phone_number full_phone_number
                             client_characteristic_id category email contact_phone].freeze

  scope :id_asc, -> { order('id asc') }
  scope :in_department, ->(department) { where department_id: department }
  scope :in_city, ->(city) { where department_id: Department.in_city(city) }

  belongs_to :department, optional: true
  belongs_to :client_characteristic, optional: true
  has_many :service_jobs, inverse_of: :client, dependent: :restrict_with_error
  has_many :devices, -> { distinct }, through: :service_jobs, source: :item, class_name: 'Item'
  has_many :orders, as: :customer, dependent: :destroy
  has_many :purchases, class_name: 'Sale', inverse_of: :client, dependent: :nullify
  has_many :history_records, as: :object
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :sale_items, through: :purchases
  has_many :sales, inverse_of: :client, dependent: :nullify
  has_many :free_jobs, class_name: 'Service::FreeJob', dependent: :restrict_with_error
  has_many :quick_orders, dependent: :restrict_with_error
  has_many :trade_in_devices, inverse_of: :client, dependent: :restrict_with_error

  accepts_nested_attributes_for :comments, allow_destroy: true, reject_if: proc { |attr| attr['content'].blank? }
  accepts_nested_attributes_for :client_characteristic, allow_destroy: true

  delegate :client_category, to: :client_characteristic, allow_nil: true
  delegate :city, to: :department, allow_nil: true

  # attr_accessible :name, :surname, :patronymic, :birthday, :email, :phone_number, :full_phone_number,
  #                 :phone_number_checked, :card_number, :admin_info, :comments_attributes, :comment,
  #                 :contact_phone, :category, :client_characteristic_attributes

  validates_presence_of :name, :surname, :phone_number, :full_phone_number, :category, :department
  validates_uniqueness_of :full_phone_number
  validates_uniqueness_of :card_number, unless: proc { |client| client.card_number.blank? }
  validates_inclusion_of :category, in: CATEGORIES.keys
  validates_associated :comments
  validates_associated :client_characteristic
  validate :restricted_attributes, unless: proc { User.current.any_admin? or User.current.able_to?(:edit_clients) }
  validates_acceptance_of :phone_number_checked
  before_destroy :send_mail

  after_initialize do
    self.category ||= 0
  end

  def self.search(params)
    clients = Client.all

    if (query = params[:client_q] || params[:client] || params[:phone_number]).present?
      query = query.sub(/\+?7[\s(]\d{3}\)?\s\d{3}-\d{2}-?\d{2}/) { |m| m.gsub(/\D+/, '') }
      query.chomp.split(/\s+/).each do |q|
        clients = clients.where [
          'LOWER(clients.surname) LIKE :q OR LOWER(clients.name) LIKE :q OR LOWER(clients.patronymic) LIKE :q OR clients.full_phone_number LIKE :q OR clients.phone_number LIKE :q OR LOWER(clients.card_number) LIKE :q', { q: "%#{q.mb_chars.downcase}%" }
        ]
      end
    end

    clients
  end

  def city=(value)
    self.department = Department.main_branches.find_by(city: value)
  end

  def full_name
    [surname, name, patronymic].join ' '
  end

  def short_name
    [name, surname.presence, questionnaire_icon].compact.join(' ').html_safe
  end

  def questionnaire_icon
    '*' unless birthday?
  end

  def name_phone
    "#{short_name} / #{human_phone_number}"
  end

  def presentation
    name_phone
  end
  alias to_s presentation

  def human_phone_number
    ActionController::Base.helpers.number_to_phone full_phone_number || phone_number, area_code: true
  end

  def comment=(content)
    comments.build content: content unless content.blank?
  end

  def purchases_sum
    sale_items.all.to_a.sum(&:sum)
  end

  def discount_value
    # Discount.for_sum purchases_sum
  end

  def creator
    history_records.first.try :user
  end

  def category_name
    client_category.present? ? client_category.name : nil
  end

  def category_color
    client_category.present? ? client_category.color : '#000000'
  end

  def characteristic
    client_characteristic.present? ? client_characteristic.comment : nil
  end

  def category_s
    CATEGORIES[category || 0]
  end

  private

  def restricted_attributes
    if (changed_attrs = changed & RESTRICTED_ATTRIBUTES).any? && persisted?
      changed_attrs.each { |a| errors.add(a.to_sym, I18n.t('errors.messages.changing_denied')) }
    end
  end

  def send_mail
    DeletionMailer.notice({ presentation: presentation }, User.current.presentation, DateTime.current).deliver_later
  end
end
