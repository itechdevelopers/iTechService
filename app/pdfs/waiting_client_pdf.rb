class WaitingClientPdf < Prawn::Document
  require 'prawn/measurement_extensions'

  def initialize(waiting_client, view)
    @waiting_client = waiting_client
    @department = @waiting_client.electronic_queue.department
    @view = view

    super page_size: [80.mm, page_height], page_layout: :portrait, margin: [10, 5, 10, 24]
    font_families.update 'DroidSans' => {
      normal: "#{Rails.root}/app/assets/fonts/droidsans-webfont.ttf",
      bold: "#{Rails.root}/app/assets/fonts/droidsans-bold-webfont.ttf"
    }
    font 'DroidSans'
    client_part
    encrypt_document permissions: { modify_contents: false }
  end

  def page_height_mm
    page_height / 1.mm
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
      text @view.t("waiting_clients.pdf.your_queue_number"), align: :center, style: :bold
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
      text waiting_client.electronic_queue.check_info
    end
  end

  def logo
    return unless department.logo_path
    image department.logo_path, width: 50, at: [0, cursor]
  end

  def page_height
    line_height_medium = 13
    line_height_small = 12
    medium_symbol_lines = count_lines(waiting_client.queue_item.annotation, 27)
    small_symbol_lines = count_lines(waiting_client.electronic_queue.check_info, 32)
    height = (line_height_medium * medium_symbol_lines + line_height_small * small_symbol_lines + 130)
    height > 255 ? height : 255
  end

  def count_lines(text, max_chars_per_line = 30)
    return 0 if text.blank?

    lines = 0
    current_line_chars = 0

    # Разбиваем текст на строки, сохраняя пустые строки
    text.lines(chomp: true).each do |line|
      # Обрабатываем каждую строку отдельно
      line.split(/\s+/).each do |word|
        word = word.strip

        # Проверяем, поместится ли слово в текущую строку
        if current_line_chars + word.length + (current_line_chars > 0 ? 1 : 0) > max_chars_per_line
          lines += 1
          current_line_chars = word.length
        else
          current_line_chars += word.length + (current_line_chars > 0 ? 1 : 0)
        end
      end

      # Завершаем текущую строку
      lines += 1
      current_line_chars = 0
    end

    lines
  end
end
