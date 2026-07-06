class UserSettings < ApplicationRecord
  # Orders page sections a user can pre-filter. Single source of truth:
  # migration, strong params, the settings form and the orders controller
  # all iterate over this list, so adding a tab means one line here + columns.
  SECTIONS = %w[spare_parts not_spare_parts archive].freeze

  belongs_to :user

  attribute :fixed_main_menu, :boolean, default: false
  attribute :auto_department_detection, :boolean, default: true
  attribute :receive_location_task_notifications, :boolean, default: true
  attribute :receive_glass_sticking_notifications, :boolean, default: true
  attribute :default_order_department_ids, :integer, array: true, default: []
  attribute :default_order_statuses, :string, array: true, default: []

  SECTIONS.each do |section|
    attribute :"default_#{section}_department_ids", :integer, array: true, default: []
    attribute :"default_#{section}_statuses", :string, array: true, default: []
  end

  # Every order-default array column, so normalization covers point-1 globals
  # and all section-scoped columns without repetition.
  ORDER_DEFAULT_ATTRS = (['default_order'] + SECTIONS.map { |s| "default_#{s}" })
                        .flat_map { |p| ["#{p}_department_ids", "#{p}_statuses"] }
                        .freeze

  before_validation :strip_blank_order_defaults

  private

  # simple_form prepends a hidden blank field before each multi-select, so an
  # untouched list arrives as [""] / [nil]. Left as-is that reads as "present"
  # and shorts out the layered fallback in OrdersController, so we compact it.
  def strip_blank_order_defaults
    ORDER_DEFAULT_ATTRS.each do |attr|
      value = public_send(attr)
      next unless value.is_a?(Array)

      public_send("#{attr}=", value.reject { |e| e.to_s.strip.empty? })
    end
  end
end
