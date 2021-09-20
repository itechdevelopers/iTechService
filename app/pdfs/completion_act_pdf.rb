# encoding: utf-8
require "prawn/measurement_extensions"

class CompletionActPdf < Prawn::Document
  attr_reader :view_context

  def initialize(service_job, view_context)
    super page_size: 'A4', page_layout: :portrait
    @view_context = view_context
    department = service_job.department
    base_font_size = 7
    page_width = 530

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
    image department.logo_path, fit: [100, 30], at: [20, cursor]

    # Organization info
    organization = Setting.organization(department)

    text "Сервисный центр «#{department.brand_name}» #{organization}", align: :right
    text "Юр. Адрес: #{organization}, #{Setting.legal_address(department)}", align: :right
    text "#{Setting.ogrn_inn(department)}", align: :right

    move_down font_size
    stroke do
      line_width 2
      horizontal_line 0, page_width
    end
    move_down font_size

    text "Фактический адрес: #{Setting.address(department)}", align: :right

    # Contact info
    move_down font_size
    text 'График работы:', align: :right, style: :bold
    text Setting.schedule(department), align: :right
    move_down font_size
    [
      "e-mail: #{Setting.email(department)}",
      "Конт. тел.: #{Setting.contact_phone(department)}",
      "сайт: #{Setting.site(department)}"
    ].each do |str|
      text str, align: :right
    end
    move_up font_size * 6

    # Title
    text "Акт выполненных работ № 001", style: :bold, align: :center
    text "по заказ-наряду № #{service_job.ticket_number}", style: :bold, align: :center
    text "от #{service_job.received_at.strftime('%d.%m.%Y')}", style: :bold, align: :center
    move_down font_size * 2

    # Client info
    text "Клиент: #{service_job.client_full_name} Телефон: #{view_context.number_to_phone service_job.client_phone}"
    text "Адрес: #{service_job.client_address}"
    move_down font_size

    # Table
    device_group = service_job.device_group.presence || /iPhone|iPad|MacBook|iMac|Mac mini/.match(service_job.type_name)
    table [
            ["Торговая марка: #{service_job.trademark}", "imei: #{service_job.imei}"],
            ["Группа изделий: #{device_group}", "Серийный номер: #{service_job.serial_number}"],
            ["Модель: #{service_job.type_name}", "Комплектность: #{service_job.completeness}"],
          ], width: 530

    table [["Заявленный дефект клиентом", service_job.claimed_defect]], width: 530 do
      column(0).width = 150
    end

    tasks_table_data = service_job.repair_tasks.map { |task| [task.name, view_context.number_to_currency(task.price)] }
    tasks_table_data += service_job.device_tasks.reject(&:is_repair?).map { |task| [task.name, view_context.number_to_currency(task.cost)] }
    tasks_table_data += [["Итого", view_context.number_to_currency(service_job.tasks_cost)]]
    table_data = [[{content:"Выполненные работы", rowspan: tasks_table_data.length+1}, 'Наименование', 'Стоимость']] + tasks_table_data

    table table_data, width: 530 do
      column(0).width = 150
    end

    tasks_comments = service_job.device_tasks.map { |task| task.user_comment }.join('. ')
    table [["Комментарий к выполненной работе", tasks_comments]], width: 530 do
      column(0).width = 150
    end

    receipt_date = service_job.received_at.strftime('%d.%m.%Y')
    done_date = service_job.done_at.strftime('%d.%m.%Y')
    duration = calculate_duration(service_job.received_at, service_job.done_at)
    return_date = service_job.archived_at&.strftime('%d.%m.%Y')
    table [["Дата приёма: #{receipt_date}", "Дата завершения ремонта: #{done_date}", "Срок выполнения: #{duration}", "Дата выдачи устройства: #{return_date}"]], width: 530
    move_down font_size

    sum_in_words = RuPropisju.rublej(service_job.tasks_cost)
    text "Стоимость услуг по договору составляет: #{sum_in_words}"

    move_down font_size

    # Text
    text "Сервисный центр уведомляет, а заказчик принимает к сведению информацию о том, что гарантия предоставлена исключительно на заменённые детали. Сервисный центр оставляет за собой право отказать заказчику в проведении гарантийного ремонта в случае, если в результате проверки аппарата будет установлено, что заявленная заказчиком неисправность не связана с предыдущим ремонтом (ст.5 п.6 «Закон о защите прав потребителей»)."
    move_down font_size

    text "Оборудование не подлежит гарантийному обслуживанию в следующих случаях:"
    table [
            ["-", "попадание влаги, жидкости, активных сред на блоки, узлы, платы, отдельные элементы и компоненты устройства"],
            ["-", "наличие внешних либо внутренних механических повреждений устройства"],
            ["-", "нарушение либо удаление гарантийной пломбы, а также обнаружение попытки самостоятельного вскрытия или ремонт устройства"],
            ["-", "стёрт, удалён либо не читаем серийный номер устройства"]
          ], cell_style: {borders: [], padding: 1} do
      column(0).style padding_left: 10, padding_right: 10
    end
    move_down font_size

    text "Гарантия не распространяется на неисправности, вызванные использованием не оригинальных устройств или приспособлений (аксессуаров). Гарантийные требования должны быть предъявлены в течение гарантийного срока немедленно после обнаружения неисправности или дефекта. Выполнение гарантийного ремонта продлевает срок гарантии на время его выполнения, включая дату приёма и уведомления клиента об окончании ремонта. (Ст.20 п.3 «Закона о защите прав потребителей»)."
    move_down font_size

    text "Сервисный ценр предпримет все необходимые действия для устранения недостатков выполненной работы по требованию потребителя в срок до 60 рабочих дней (Ст.30 «Закон о защите прав потребителей»)."
    move_down font_size

    text "Установленная гарантия не обеспечивает возмещение затрат, связанных с транспортировкой оборудования до местонахождения сервисного центра #{organization} «#{department.brand_name}»."
    move_down font_size

    text "Сервисный центр не несёт ответственности за любой косвенный ущерб, вызванный проявлением недостатков или дефектов в устройстве, ущерб, причинённый другим устройствам или оборудованию, работающим в сопряжении с данным устройством."
    move_down font_size

    text "Сервисный центр предоставляет гарантию на заменённые детали в течение 90 дней с момента выдачи аппарата."
    move_down font_size * 3

    text "Внимание заказчика!", style: :bold, align: :center, size: 8
    move_down font_size

    text "Просьба проверять комплектацию принимаемого из ремонта оборудования в присутствии сотрудника приёмного отдела.
Сервисный центр оставляет за собой право не принимать претензии к комплектности выданного оборудования при условии наличия подписи заказчика на данной квитанции.", style: :bold, size: 8
    move_down font_size * 3

    text "Работы по Заказ-наряду выполнены в полном объёме в срок. Недостатки в результаты работ не выявлены. Изделие проверено в моём присутствии, претензий по качеству работ и комплектности изделия нет. Оплату выполненных работ гарантирую."
    move_down font_size * 3

    table [
            ["", "_" * 70, "", "_" * 70],
            ["", "Подпись заказчика", "", "ФИО Заказачика"]
          ], cell_style: {borders: [], padding: 1} do
      column(0).width = 20
      column(2).width = 40
      row(1).style padding_left: 20
    end
    move_down font_size * 3

    text "Клиент-менеджер выдавший устройство"
    stroke do
      line_width 1
      horizontal_line 140, 530
    end
    move_down font_size
    draw_text "Подпись", at: [200, cursor]
    draw_text "Штамп исполнителя", at: [400, cursor]
  end

  private

  def calculate_duration(from_date, to_date)
    view_context.distance_of_time_in_words from_date, to_date, scope: 'datetime.distance_in_words.short'
  end
end