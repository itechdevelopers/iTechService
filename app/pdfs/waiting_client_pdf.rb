class WaitingClientPdf < Prawn::Document
  require 'prawn/measurement_extensions'

  def initialize(waiting_client, view)
    @waiting_client = waiting_client
    @department = @waiting_client.electronic_queue.department
    @view = view

    super page_size: [80.mm, 90.mm], page_layout: :portrait, margin: [10, 5, 10, 24]
    font_families.update 'DroidSans' => {
      normal: "#{Rails.root}/app/assets/fonts/droidsans-webfont.ttf",
      bold: "#{Rails.root}/app/assets/fonts/droidsans-bold-webfont.ttf"
    }
    font 'DroidSans'
    client_part
    encrypt_document permissions: { modify_contents: false }
  end

  def page_height_mm
    90
  end

  private

  attr_accessor :department, :waiting_client, :view

  def client_part
    logo

    font_size 10 do
      text_box waiting_client.created_at.strftime("%H:%M\n%d.%m.%Y"), at: [bounds.right - 70, cursor], width: 60, align: :left
    end

    move_down 50
    font_size 12 do
      text @view.t("waiting_clients.pdf.your_queue_number"), align: :center, inlign_format: true, style: :bold
    end

    move_down 5
    font_size 30 do
      text waiting_client.ticket_number, align: :center, style: :bold
    end
    move_down 4
    font_size 12 do
      text waiting_client.queue_item.annotation, align: :center
    end

    move_cursor_to 50
    font_size 10 do
      text @view.t("waiting_clients.pdf.discover_of_goods")
      text @view.t("waiting_clients.pdf.site_url")
      stroke_line [0, cursor], [80, cursor]
    end
  end

  def logo
    return unless department.logo_path
    image department.logo_path, width: 50, at: [0, cursor]
  end
end