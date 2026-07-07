class OrderFeedback < ApplicationRecord
  MAX_POSTPONE = 5

  belongs_to :order

  scope :in_department, ->(department) { where(order_id: Order.where(department: department)) }
  scope :inactive,  -> { where scheduled_on: nil }
  scope :actual,    -> { where('scheduled_on <= ?', Time.current) }
  scope :old_first, -> { order 'created_at ASC' }
  scope :new_first, -> { order 'created_at DESC' }

  delegate :number, :customer_short_name, :object, :department, :department_id, to: :order, allow_nil: true

  # Two reminders derived from the order's desired_date:
  #  1. midpoint between created_at and desired_date
  #  2. one day before desired_date
  # No reminders when desired_date is blank.
  def self.schedule_for(order)
    return if order.desired_date.blank?

    created  = order.created_at || Time.current
    deadline = order.desired_date.in_time_zone.change(hour: 10)
    midpoint = created + (deadline - created) / 2

    [midpoint, deadline - 1.day].each do |scheduled_on|
      create(order: order, scheduled_on: scheduled_on, log: initial_log(scheduled_on))
    end
  end

  def self.initial_log(scheduled_on)
    time = I18n.l(scheduled_on, format: :long)
    "[#{I18n.l(Time.current, format: :long)}] #{I18n.t('service.feedback.scheduled_on', time: time)}"
  end

  def city
    department&.city
  end

  def city_name
    city&.name
  end

  def city_color
    city&.color
  end

  def presentation
    [number, customer_short_name, object].compact.join(' / ')
  end

  def add_log(new_log)
    self.log = [log.presence, new_log].compact.join('<br/>')
  end
end
