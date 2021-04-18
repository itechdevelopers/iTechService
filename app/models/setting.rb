# frozen_string_literal: true

class Setting < ActiveRecord::Base
  TYPES = {
    address: 'string',
    address_for_check: 'string',
    app_logo_filename: 'string',
    contact_phone: 'string',
    contact_phone_short: 'string',
    data_storage_qty: 'integer',
    duck_plan: 'string',
    duck_plan_url: 'string',
    email: 'string',
    emails_for_acts: 'string',
    emails_for_orders: 'string',
    emails_for_sales_report: 'string',
    emails_for_sales_import: 'string',
    legal_address: 'string',
    meda_menu_database: 'string',
    ogrn_inn: 'string',
    organization: 'string',
    print_sale_check: 'boolean',
    schedule: 'string',
    service_tasks_models: 'json',
    show_spare_parts_qty: 'boolean',
    site: 'string',
    sms_notification_template: 'text',
    sms_gateway_uri: 'string',
    sms_gateway_lines_qty: 'integer',
    ticket_notice: 'text',
    ticket_prefix: 'string',
    request_review_text: 'string',
    request_review_time_out: 'integer'
  }.freeze

  VALUE_TYPES = %w[boolean integer string text json].freeze

  default_scope { order(:department_id, :presentation) }
  scope :for_department, ->(department) { where(department_id: department) }

  belongs_to :department
  delegate :name, to: :department, prefix: true, allow_nil: true
  validates :name, presence: true
  validates_uniqueness_of :name, scope: :department_id
  validate :json_value_correct

  before_validation do
    self.value_type ||= TYPES[name.to_sym]
    self.presentation = I18n.t("settings.#{name}", default: name.to_s.humanize) if presentation.blank?
  end

  class << self
    def get_value(name, department = Department.current)
      setting = Setting.for_department(department).find_by_name(name.to_s) || Setting.find_by(department_id: nil,
                                                                                              name: name.to_s)
      setting.present? ? setting.value : ''
    end

    private

    def method_missing(name, *arguments, &block)
      the_name = name.to_s.gsub(/\?$/, '')
      setting_type = TYPES[the_name.to_sym]
      return super if setting_type.nil?

      department = arguments.first
      value = get_value(the_name, department)

      case setting_type
      when 'boolean'
        value == '1'
      when 'integer'
        value.to_i
      when 'json'
        parse_value value
      else
        value
      end
    end

    def parse_value(value)
      return {} if value.blank?

      begin
        JSON.parse(value)
      rescue StandardError => e
        e
      end
    end
  end

  def input_type
    value_type =~ /(json|string)/ ? 'text' : value_type
  end

  private

  def json_value_correct
    return unless value_type == 'json' && !value.nil?

    begin
      JSON.parse value
      true
    rescue StandardError => e
      errors.add :value, e.message
    end
  end
end
