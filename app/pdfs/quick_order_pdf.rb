# encoding: utf-8
class QuickOrderPdf < Prawn::Document
  require 'prawn/measurement_extensions'
  include ActiveSupport::NumberHelper

  attr_reader :quick_order, :department
  
  def initialize(quick_order)
    super page_size: [80.mm, 90.mm], page_layout: :portrait, margin: [10, 24, 10, 10]
    @quick_order = quick_order
    @department = quick_order.department
    font_families.update 'DroidSans' => {
      normal: "#{Rails.root}/app/assets/fonts/droidsans-webfont.ttf",
      bold: "#{Rails.root}/app/assets/fonts/droidsans-bold-webfont.ttf"
    }
    font 'DroidSans'
    client_part
    start_new_page
    receiver_part
    encrypt_document permissions: { modify_contents: false }
  end

  def client_part
    device_kind_image
    move_down 45
    logo
    move_down 22
    font_size 24 do
      text "№ #{quick_order.number_s}", align: :center, inlign_format: true, style: :bold
    end
    font_size 10 do
      text I18n.l(quick_order.created_at, format: :date_time), align: :center, inline_format: true
    end
    move_down 4
    text department.name, align: :center
    move_down 30
    text I18n.t('tickets.user', name: quick_order.user_short_name)
    move_down 5
    stroke { horizontal_line 0, 205 }
    move_down 5
    text I18n.t('tickets.contact_phone', number: Setting.contact_phone(department))
  end

  def receiver_part
    device_kind_image
    move_down 55
    font_size 24 do
      text "№ #{quick_order.number_s}", align: :center, inlign_format: true, style: :bold
    end
    font_size 10 do
      text I18n.l(quick_order.created_at, format: :date_time), align: :center, inline_format: true
    end
    move_down 4
    text quick_order.department_name, align: :center
    text quick_order.client_short_name
    text [quick_order.client_phone, number_to_phone(quick_order.contact_phone, area_code: true).presence].compact.join(', ')
    move_down 5
    text "#{QuickOrder.human_attribute_name(:security_code)}: #{quick_order.security_code}"
    text "#{QuickOrder.human_attribute_name(:apple_id_password)}: #{quick_order.apple_id_password}"
    move_down 3
    stroke { horizontal_line 0, 205 }
    move_down 5
    text I18n.t('tickets.operations_list')
    text quick_order.quick_tasks.map(&:name).join(', ')
    move_down 5
    stroke { horizontal_line 0, 205 }
    move_down 5
    text I18n.t('tickets.user', name: quick_order.user_short_name)
  end

  private

  def logo
    return unless department.logo_path

    image department.logo_path, width: 50, at: [0, cursor-10]
  end

  def device_kind_image
    image File.join(Rails.root, "app/assets/images/#{quick_order.device_kind}.png"), height: 50, at: [70, cursor] if quick_order.device_kind.in?(QuickOrder::DEVICE_KINDS)
  end
end
