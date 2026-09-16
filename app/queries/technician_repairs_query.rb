# frozen_string_literal: true

# Сводка «сколько ремонтных работ выполнил техник» за календарный месяц
# в рамках одного подразделения.
#
# Считает то же, что отчёт technicians_jobs: закрытые ремонтные работы
# (RepairTask) плюс закрытые device_tasks ремонтных услуг, к которым работу
# так и не привязали. Без вторых цифра разошлась бы с отчётом, на который
# смотрят в мастерской. Деньги (цена, стоимость запчастей, наценка) здесь
# не считаются вовсе.
class TechnicianRepairsQuery
  Work = Struct.new(:name, :service_job_id, :service_job_presentation, :done_at, keyword_init: true)

  Row = Struct.new(:user, :works, keyword_init: true) do
    def count
      works.size
    end
  end

  def initialize(department:, month: Date.current)
    @department = department
    @month = month.to_date.beginning_of_month
  end

  # @return [Array<Row>] лидеры сверху; техники локации «ремонт» без работ
  #   тоже попадают в список — иначе человек с нулём не увидит себя в таблице.
  def call
    works = works_by_performer

    users_for(works.keys)
      .map { |user| Row.new(user: user, works: works.fetch(user.id, []).sort_by(&:done_at).reverse) }
      .sort_by { |row| [-row.count, row.user.short_name.to_s] }
  end

  # Число для одного человека считается запросами, а не через `call`: топбар
  # рендерится на каждой странице приложения.
  def count_for(user)
    repair_tasks.where(device_tasks: { performer_id: user.id }).count +
      orphan_device_tasks.where(performer_id: user.id).count
  end

  private

  attr_reader :department, :month

  def works_by_performer
    works = Hash.new { |hash, key| hash[key] = [] }

    repair_tasks.includes(:repair_service, device_task: { service_job: %i[item device_type] }).each do |repair_task|
      device_task = repair_task.device_task
      next if device_task.performer_id.blank?

      works[device_task.performer_id] << build_work(device_task, repair_task.name)
    end

    orphan_device_tasks.includes(service_job: %i[item device_type]).each do |device_task|
      next if device_task.performer_id.blank?

      works[device_task.performer_id] << build_work(device_task, I18n.t('personnel.repairs.without_service'))
    end

    works
  end

  def build_work(device_task, name)
    service_job = device_task.service_job

    Work.new(
      name: name.presence || I18n.t('personnel.repairs.without_service'),
      service_job_id: service_job&.id,
      service_job_presentation: service_job&.presentation,
      done_at: device_task.done_at
    )
  end

  def repair_tasks
    RepairTask.joins(:device_task).where(device_task_id: done_device_tasks)
  end

  def orphan_device_tasks
    done_device_tasks
      .joins(task: :product)
      .left_joins(:repair_tasks)
      .where("products.code LIKE 'repair%'")
      .where(repair_tasks: { id: nil })
  end

  def done_device_tasks
    DeviceTask.in_department(department).where(done_at: month_range)
  end

  def month_range
    month.beginning_of_month.beginning_of_day..month.end_of_month.end_of_day
  end

  # Уволенные с работами за месяц остаются в таблице: иначе итог не сойдётся
  # с отчётом. Нулевые строки добавляются только для действующих техников.
  def users_for(performer_ids)
    (User.where(id: performer_ids).to_a + technicians).uniq
  end

  def technicians
    User.active.located_at(Location.in_department(department).repair).to_a
  end
end
