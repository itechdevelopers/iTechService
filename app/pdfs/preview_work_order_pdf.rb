# encoding: utf-8
# frozen_string_literal: true

# PDF generator for work order preview (before ServiceJob is saved)
# Takes a hash of data instead of a persisted ServiceJob object
class PreviewWorkOrderPdf < Prawn::Document
  require "prawn/measurement_extensions"

  def initialize(data, view_context)
    super page_size: 'A4', page_layout: :portrait, top_margin: 10

    @data = data
    @view_context = view_context
    @department = data[:department]
    @client = data[:client]
    @task_ids = data[:task_ids] || []

    base_font_size = 7
    page_width = 530

    font_families.update 'DroidSans' => {
      normal: "#{Rails.root}/app/assets/fonts/droidsans-webfont.ttf",
      bold: "#{Rails.root}/app/assets/fonts/droidsans-bold-webfont.ttf"
    }

    font 'DroidSans'
    font_size base_font_size

    # Client surname initial (or placeholder)
    client_initial = @client&.surname&.first || '?'
    draw_text "«#{client_initial}»",
              at: [page_width/2-10, cursor-2*base_font_size],
              size: base_font_size*2

    # Logo
    if @department&.logo_path.present?
      image @department.logo_path, fit: [100, 4*base_font_size], at: [20, cursor]
    end

    # Organization info
    organization = @department ? Setting.organization(@department) : ''

    if @department
      text "Сервисный центр «#{@department.brand_name}» #{organization}, ИНН #{Setting.ogrn_inn(@department)}", align: :right
      text "Юр. Адрес: #{organization}, #{Setting.legal_address(@department)}", align: :right
      text "Фактический адрес: #{Setting.address(@department)}", align: :right
    end

    move_down 4
    stroke do
      line_width 2
      horizontal_line 0, page_width
    end

    # Contact info
    move_down 2
    if @department
      text 'График работы:', align: :right, style: :bold
      text Setting.schedule(@department), align: :right
      move_down 2
      [
        "e-mail: #{Setting.email(@department)}",
        "Конт. тел.: #{Setting.contact_phone(@department)}",
        "сайт: #{Setting.site(@department)}"
      ].each do |str|
        text str, align: :right
      end
    end
    move_up font_size * 6

    # Title
    text "Заказ-наряд № #{@data[:ticket_number]}", style: :bold, align: :center
    received_at = @data[:received_at] || Time.current
    text "Дата приёма: #{received_at.strftime('%d.%m.%Y')}", style: :bold, align: :center
    move_down font_size

    # Client info
    client_full_name = @client&.full_name || @data[:client_full_name] || ''
    client_phone = @client&.phone_number || @data[:contact_phone] || ''
    text "Клиент: #{client_full_name} Телефон: #{@view_context.number_to_phone(client_phone)}"
    text "Адрес: #{@data[:client_address]}"
    move_down font_size + 2

    # Table
    device_group = @data[:device_group].presence || /iPhone|iPad|MacBook|iMac|Mac mini/.match(@data[:type_name].to_s)
    table [
      ["Торговая марка: #{@data[:trademark]}", "imei: #{@data[:imei]}"],
      ["Группа изделий: #{device_group}", "Серийный номер: #{@data[:serial_number]}"],
      ["Модель: #{@data[:type_name]}", "Комплектность: #{@data[:completeness]}"],
    ], width: page_width

    table [
            ["Заявленный дефект клиентом", @data[:claimed_defect]],
            ["Внешний вид/Состояние устройства", @data[:device_condition]],
            ["Комментарии/Особые отметки", @data[:client_comment]],
            ["Требование клиента", ''],
            ["Вид работы", @data[:type_of_work]],
            ["Ориентировочная стоимость ремонта", @data[:estimated_cost_of_repair]]
          ], width: page_width do
      column(0).width = 150
    end

    move_down font_size

    # Service conditions (from task_ids)
    conditions = collect_service_conditions
    text "Клиент ознакомлен и согласен с условиями проведения ремонта:"
    conditions_table_data = conditions.each_with_index.map { |c, i| ["#{i + 1}.", '', { content: c.content }] }
    table conditions_table_data, cell_style: { borders: [], padding: 1 } do
      column(0).style width: 12
      column(1).style width: 0
    end

    move_down font_size
    text "С условиями обслуживания и сроками его проведения согласен, правильность заполнения заказа подтверждаю. Сервисный центр оставляет за собой право отказать в проведении гарантийного обслуживания в случае нарушения условий гарантии."
    move_down font_size

    user_full_name = @data[:user]&.full_name || ''
    table [
            ["", "_" * 70, "", "_" * 60],
            ["", "«Мною прочитано, возражений не имею»", "", "Подпись"],
            ["", "Аппарат принял: #{user_full_name}", "", "_" * 60],
            ["", "", "", "Подпись приёмщика"],
          ], cell_style: {borders: [], padding: 0} do
      column(0).width = 20
      column(2).width = 40
      row(1).style padding_left: 20
      row(2).style padding_top: 10
      row(3).style padding_left: 20
    end

    move_down font_size
    brand_name = @department&.brand_name || ''
    text "Я, _____________________________________________________________________, даю согласие сервисному центру «#{brand_name}» #{organization} на обработку его персональных данных в целях обеспечения соблюдения закона и иных нормативных актов РФ, включая любые действия, предусмотренные Федеральным законом №152-ф3 «О персональных данных». Настоящее соглашение дано, в том числе, для осуществления передачи сервисным центром персональных данных клиента третьим лицам, с которыми у сервисного центра заключены соглашения содержащие условия о конфиденциальности, включая транспортную передачу, а также хранения и обработки оператором и третьими лицами в целях и в сроки, предусмотренные действующим законодательством Российской Федерации. Указание клиентом своего контактного телефона означает его согласие с вышеперечисленными действиями сервисного центра."

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

  def collect_service_conditions
    return ServiceCondition.all.to_a if @task_ids.blank?

    conditions = ServiceCondition.joins(:tasks)
                                  .where(tasks: { id: @task_ids })
                                  .distinct
                                  .order(:position)
                                  .to_a

    conditions.presence || ServiceCondition.all.to_a
  end
end
