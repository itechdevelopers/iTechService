# frozen_string_literal: true

# Сверка расчётов с 1С по номеру работы. Нужна там, где push не сработал:
# колбэк об оплате потерялся в сети, либо чек вообще пробили руками и наш
# отложенный чек с ним никак не связан.
class ReconcileServiceChecksJob < ApplicationJob
  queue_as :default

  # Чек редко рассчитывают мгновенно — пока клиент идёт к кассе, сверять нечего.
  SETTLE_DELAY = 20.minutes

  def perform
    reconcile(pending_payments)
    reconcile(unmatched_manual)
  end

  private

  # Отправленные чеки, по которым оплата так и не пришла.
  def pending_payments
    ServiceJobCheckout.where(state: ServiceJobCheckout.states[:sent])
                      .where('sent_at < ?', SETTLE_DELAY.ago)
  end

  # Ручные переносы, которым ещё не нашли чек в 1С.
  def unmatched_manual
    ServiceJobCheckout.where(manual: true, matched_at: nil)
                      .where(state: [ServiceJobCheckout.states[:paid], ServiceJobCheckout.states[:archived]])
  end

  def reconcile(scope)
    client = ServiceCheckClient.new

    scope.includes(:service_job).find_each do |checkout|
      job_number = checkout.service_job&.ticket_number
      next if job_number.blank?

      result = client.find_check(job_number)
      data = result[:data].is_a?(Hash) ? result[:data] : {}
      next unless result[:success] && data['found']

      apply(checkout, data)
    end
  end

  def apply(checkout, data)
    if checkout.manual?
      # Работа уже закрыта сотрудником — сверка лишь подтягивает реквизиты
      # настоящего чека, чтобы старшему было что сравнить с введённым номером.
      checkout.update!(matched_at: Time.current,
                       check_guid: data['check_guid'].presence || checkout.check_guid,
                       paid_total: data['total'],
                       payments: Array(data['payments']),
                       paid_at: checkout.paid_at || parsed_time(data['paid_at']))
      Rails.logger.info "[ServiceCheck] Manual checkout #{checkout.id} matched with 1C check #{data['check_number']}"
    else
      ServiceJobs::RegisterCheckPayment.call(checkout: checkout, attributes: data)
      checkout.update!(matched_at: Time.current)
      Rails.logger.info "[ServiceCheck] Checkout #{checkout.id} settled by reconciliation, check #{data['check_number']}"
    end
  end

  def parsed_time(value)
    Time.zone.parse(value.to_s)
  rescue ArgumentError
    nil
  end
end
