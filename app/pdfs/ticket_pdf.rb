class TicketPdf < Prawn::Document
  require 'prawn/measurement_extensions'
  require 'barby/barcode/ean_13'
  require 'barby/outputter/prawn_outputter'

  attr_reader :service_job, :department, :view

  def initialize(service_job, view, part=nil)
    super page_size: [80.mm, 90.mm], page_layout: :portrait, margin: [10, 22, 10, 10]
    @service_job = service_job
    @department = service_job.department
    @view = view
    font_families.update 'DroidSans' => {
      normal: "#{Rails.root}/app/assets/fonts/droidsans-webfont.ttf",
      bold: "#{Rails.root}/app/assets/fonts/droidsans-bold-webfont.ttf"
    }
    font 'DroidSans'
    client_part unless part.to_i == 2
    start_new_page if part.nil?
    receiver_part unless part.to_i == 1
    encrypt_document permissions: { modify_contents: false }
  end

  def client_part
    logo
    vertical_line y-60, y-10, at: 60
    stroke
    font_size 10 do
      span 125, position: :right do
        text Setting.site(department)
        text Setting.email(department)
        text Setting.schedule(department)
      end
    end
    move_cursor_to 180
    font_size 24 do
      text "№ #{service_job.ticket_number}", align: :center, inlign_format: true, style: :bold
    end
    text service_job.created_at.strftime('%H:%M %d.%m.%Y'), align: :center
    text Setting.address(department), align: :center
    move_down 5
    text view.t('tickets.user', name: service_job.user_short_name)
    move_down 5
    text I18n.t('tickets.contact_phone', number: Setting.contact_phone(department))
    move_down 5
    horizontal_line 0, 205
    stroke
    move_down 5
    font_size 10 do
      text Setting.ticket_notice(department)
    end
    barcode
  end

  def receiver_part
    logo
    move_down 8
    span 140, position: :right do
      font_size 22 do
        text @service_job.ticket_number, inlign_format: true, style: :bold
      end
      text @service_job.created_at.strftime('%H:%M %d.%m.%Y')
      text Setting.address(department)
    end
    move_down 10
    text @service_job.client_short_name
    text @view.number_to_phone @service_job.client.full_phone_number || @service_job.client.phone_number, area_code: true
    text "#{@view.t('tickets.service_job_contact_phone', number: @view.number_to_phone(@service_job.contact_phone, area_code: true))}"
    move_down 5
    text "#{ServiceJob.human_attribute_name(:security_code)}: #{@service_job.security_code_display}"
    move_down 5
    text @view.t('tickets.operations_list')
    text @service_job.tasks.map{|t|t.name}.join(', ')
    move_down 5
    text @view.t('tickets.user', name: @service_job.user_short_name)
    move_down 5
    text @service_job.presentation
    barcode
  end

  private

  def logo
    image department.logo_path, width: 50, at: [0, cursor]
  end

  def barcode
    num = @service_job.ticket_number
    code = '0'*(12-num.length) + num
    code = Barby::EAN13.new code
    outputter = Barby::PrawnOutputter.new code
    outputter.annotate_pdf self, height: 25, xdim: 1.7, x: 20, margin: 2
  end
end
