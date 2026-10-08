# frozen_string_literal: true
module Telephony
  class CallerContext
    def initialize(user, number)
      @user = user
      @number = Number.normalize(number)
      @routes = Rails.application.routes.url_helpers
    end
    def call
      result = { number: @number, clients: [] }
      return result unless @number
      # Match full normalized numbers and the legacy ten-digit phone field.
      variants = [@number, '8' + @number[1..-1], @number[1..-1]]
      clients = Client.where("REGEXP_REPLACE(full_phone_number, '[^0-9]', '', 'g') IN (:phones) OR REGEXP_REPLACE(phone_number, '[^0-9]', '', 'g') IN (:phones) OR REGEXP_REPLACE(contact_phone, '[^0-9]', '', 'g') IN (:phones)", phones: variants).order(:id).limit(10)
      clients.each do |client|
        next unless Pundit.policy!(@user, client).show?
        entities = []
        client.orders.device.actual_orders.newest.limit(20).each do |order|
          next unless Pundit.policy!(@user, order).show?
          entities << { kind: 'order', title: "Заявка №#{order.number}: #{order.object}", url: @routes.order_path(order) }
        end
        client.service_jobs.pending.not_at_archive.newest.limit(20).each do |job|
          next unless Pundit.policy!(@user, job).show?
          entities << { kind: 'service_job', title: "Устройство в работе №#{job.id}: #{job.item&.product&.name}", url: @routes.service_job_path(job) }
        end
        client.quick_orders.undone.created_desc.limit(20).each do |job|
          next unless Pundit.policy!(@user, job).show?
          entities << { kind: 'quick_order', title: "Быстрая работа №#{job.number_s}: #{job.device_kind}", url: @routes.quick_order_path(job) }
        end
        result[:clients] << { name: client.full_name, url: @routes.client_path(client), entities: entities }
      end
      # Clients with work in progress appear first, then client cards.
      result[:clients].sort_by! { |client| client[:entities].empty? ? 1 : 0 }
      result
    end
  end
end
