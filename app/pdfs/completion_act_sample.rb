# frozen_string_literal: true

# Демо-заказ для проверочного акта. Отвечает на всё, что CompletionActPdf читает у
# ServiceJob: если акт начнёт читать новое поле заказа, его нужно добавить и сюда,
# иначе проверочный акт упадёт с NoMethodError.
class CompletionActSample
  Client = Struct.new(:surname)
  RepairTask = Struct.new(:name, :price)
  DeviceTask = Struct.new(:name, :cost, :user_comment, :repair) do
    def is_repair?
      repair
    end
  end

  attr_reader :department, :received_at, :done_at, :archived_at

  def initialize(department)
    @department = department
    @archived_at = Time.current
    @done_at = @archived_at - 1.day
    @received_at = @archived_at - 3.days
  end

  def client
    Client.new('Образцов')
  end

  def client_full_name
    'Образцов Иван Иванович'
  end

  def client_phone
    '79990000000'
  end

  def client_address
    'г. Владивосток, ул. Примерная, 1'
  end

  def ticket_number
    '00000000000'
  end

  def trademark
    'Apple'
  end

  def device_group
    'iPhone'
  end

  def type_name
    'iPhone 13 128GB Midnight'
  end

  def imei
    '000000000000000'
  end

  def serial_number
    'SAMPLE000000'
  end

  def completeness
    'Устройство'
  end

  def claimed_defect
    'Не включается'
  end

  def repair_tasks
    [RepairTask.new('Замена дисплея', 5000)]
  end

  def device_tasks
    [
      DeviceTask.new('Замена дисплея', 5000, 'Дисплей заменён', true),
      DeviceTask.new('Диагностика', 500, 'Устройство проверено', false)
    ]
  end

  def tasks_cost
    5500
  end
end
