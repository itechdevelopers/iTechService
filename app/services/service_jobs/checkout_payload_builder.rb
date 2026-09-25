# frozen_string_literal: true

module ServiceJobs
  # Состав отложенного чека для 1С. Позиция чека — платная задача работы:
  # уходит номенклатура задачи, её цена для клиента и себестоимость запчастей,
  # потраченных именно на эту задачу.
  class CheckoutPayloadBuilder
    APP_HOST = 'https://ise.itech.pw'

    attr_reader :checkout, :service_job

    def initialize(checkout)
      @checkout = checkout
      @service_job = checkout.service_job
    end

    def self.call(checkout)
      new(checkout).call
    end

    def call
      { check: check_attributes }
    end

    # Тот же состав кладётся в items_snapshot: после отправки задачи можно
    # переоткрыть и изменить, а разбирать расхождение придётся по тому, что
    # реально ушло в кассу.
    def items
      @items ||= service_job.device_tasks.paid.map { |device_task| item_for(device_task) }
    end

    def total
      items.sum { |item| item[:price] * item[:quantity] }
    end

    private

    def check_attributes
      {
        uid: checkout.uid,
        job_number: service_job.ticket_number,
        job_url: "#{APP_HOST}/service_jobs/#{service_job.id}",
        department_id: service_job.department&.code_one_c.to_s,
        created_at: Time.current.iso8601,
        initiator: initiator_attributes,
        client: client_attributes,
        total: total,
        items: items
      }
    end

    def initiator_attributes
      initiator = checkout.initiator
      return {} if initiator.nil?

      { id: initiator.id, name: initiator.short_name }
    end

    def client_attributes
      client = service_job.client

      {
        phone: PhoneNormalizer.normalize(client&.full_phone_number || service_job.contact_phone),
        name: client&.full_name&.squish,
        ise_id: client&.id
      }
    end

    def item_for(device_task)
      product = device_task.task&.product

      {
        line_id: device_task.id,
        article: product&.article,
        name: device_task.task&.name,
        quantity: 1,
        price: device_task.cost.to_f,
        cost_price: cost_price_for(device_task),
        kind: device_task.is_repair? ? 'repair' : 'service',
        warranty_term: product&.warranty_term
      }
    end

    # Закупочной цены может не быть вовсе — у товара нет ни проведённой партии,
    # ни заданной цены. Количество не умножаем: так же считает
    # RepairTask#parts_cost, с которым сверяются отчёты по марже.
    def cost_price_for(device_task)
      device_task.repair_tasks.to_a.sum do |repair_task|
        repair_task.repair_parts.to_a.sum { |part| part.purchase_price.to_f }
      end
    end
  end
end
