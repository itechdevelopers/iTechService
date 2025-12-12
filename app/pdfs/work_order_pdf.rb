# encoding: utf-8

class WorkOrderPdf < Prawn::Document
  require "prawn/measurement_extensions"

  def initialize(service_job, view_context)
    super page_size: 'A4', page_layout: :portrait, top_margin: 10
    department = service_job.department
    base_font_size = 7
    page_width = 530
    # page_width = 545

    font_families.update 'DroidSans' => {
      normal: "#{Rails.root}/app/assets/fonts/droidsans-webfont.ttf",
      bold: "#{Rails.root}/app/assets/fonts/droidsans-bold-webfont.ttf"
    }

    font 'DroidSans'
    font_size base_font_size

    draw_text "«#{service_job.client.surname.first}»",
              at: [page_width/2-10, cursor-2*base_font_size],
              size: base_font_size*2

    # Logo
    image department.logo_path, fit: [100, 4*base_font_size], at: [20, cursor]

    # Organization info
    organization = Setting.organization(department)

    text "Сервисный центр «#{department.brand_name}» #{organization}, ИНН #{Setting.ogrn_inn(department)}", align: :right
    text "Юр. Адрес: #{organization}, #{Setting.legal_address(department)}", align: :right
    text "Фактический адрес: #{Setting.address(department)}", align: :right

    move_down 4
    stroke do
      line_width 2
      horizontal_line 0, page_width
    end

    # Contact info
    move_down 2
    text 'График работы:', align: :right, style: :bold
    text Setting.schedule(department), align: :right
    move_down 2
    [
      "e-mail: #{Setting.email(department)}",
      "Конт. тел.: #{Setting.contact_phone(department)}",
      "сайт: #{Setting.site(department)}"
    ].each do |str|
      text str, align: :right
    end
    move_up font_size * 6

    # Title
    text "Заказ-наряд № #{service_job.ticket_number}", style: :bold, align: :center
    text "Дата приёма: #{service_job.received_at.strftime('%d.%m.%Y')}", style: :bold, align: :center
    move_down font_size

    # Client info
    text "Клиент: #{service_job.client_full_name} Телефон: #{view_context.number_to_phone service_job.client_phone}"
    text "Адрес: #{service_job.client_address}"
    move_down font_size + 2

    # Table
    device_group = service_job.device_group.presence || /iPhone|iPad|MacBook|iMac|Mac mini/.match(service_job.type_name)
    table [
      ["Торговая марка: #{service_job.trademark}", "imei: #{service_job.imei}"],
      ["Группа изделий: #{device_group}", "Серийный номер: #{service_job.serial_number}"],
      ["Модель: #{service_job.type_name}", "Комплектность: #{service_job.completeness}"],
    ], width: page_width

    table [
            ["Заявленный дефект клиентом", service_job.claimed_defect],
            ["Внешний вид/Состояние устройства", service_job.device_condition],
            ["Комментарии/Особые отметки", service_job.client_comment],
            ["Требование клиента", ''],
            ["Вид работы", service_job.type_of_work],
            ["Ориентировочная стоимость ремонта", service_job.estimated_cost_of_repair]
          ], width: page_width do
      column(0).width = 150
    end

    move_down font_size

    # Service conditions (dynamic from database)
    conditions = collect_service_conditions(service_job)
    text "Клиент ознакомлен и согласен с условиями проведения ремонта:"
    conditions_table_data = conditions.each_with_index.map { |c, i| ["#{i + 1}.", '', { content: c.content }] }
    table conditions_table_data, cell_style: { borders: [], padding: 1 } do
      column(0).style width: 12
      column(1).style width: 0
    end

    move_down font_size
    text "С условиями обслуживания и сроками его проведения согласен, правильность заполнения заказа подтверждаю. Сервисный центр оставляет за собой право отказать в проведении гарантийного обслуживания в случае нарушения условий гарантии."
    move_down font_size

    table [
            ["", "_" * 70, "", "_" * 60],
            ["", "«Мною прочитано, возражений не имею»", "", "Подпись"],
            ["", "Аппарат принял: #{service_job&.user&.full_name}", "", "_" * 60],
            ["", "", "", "Подпись приёмщика"],
          ], cell_style: {borders: [], padding: 0} do
      column(0).width = 20
      column(2).width = 40
      row(1).style padding_left: 20
      row(2).style padding_top: 10
      row(3).style padding_left: 20
    end

    move_down font_size
    text "Я, _____________________________________________________________________, даю согласие сервисному центру «#{department.brand_name}» #{organization} на обработку его персональных данных в целях обеспечения соблюдения закона и иных нормативных актов РФ, включая любые действия, предусмотренные Федеральным законом №152-ф3 «О персональных данных». Настоящее соглашение дано, в том числе, для осуществления передачи сервисным центром персональных данных клиента третьим лицам, с которыми у сервисного центра заключены соглашения содержащие условия о конфиденциальности, включая транспортную передачу, а также хранения и обработки оператором и третьими лицами в целях и в сроки, предусмотренные действующим законодательством Российской Федерации. Указание клиентом своего контактного телефона означает его согласие с вышеперечисленными действиями сервисного центра."

    move_down font_size
    table [
            ["", "_" * 70, "", "_" * 60],
            ["", "Фамилия", "", "Подпись"]
          ], cell_style: {borders: [], padding: 0} do
      column(0).width = 20
      column(2).width = 40
      row(1).style padding_left: 20
    end
  end

  private

  def collect_service_conditions(service_job)
    # Collect unique conditions from all device_tasks
    conditions = service_job.device_tasks
      .includes(task: :service_conditions)
      .flat_map { |dt| dt.task&.service_conditions&.to_a || [] }
      .uniq
      .sort_by(&:position)

    # Fallback to all conditions if none are assigned
    conditions.presence || ServiceCondition.all.to_a
  end
end