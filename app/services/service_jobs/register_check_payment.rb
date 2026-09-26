# frozen_string_literal: true

module ServiceJobs
  # Факт оплаты, пришедший из 1С: фиксируем чек и пробуем закрыть работу.
  # Закрыть удаётся не всегда — за время, пока чек ждал кассу, работу могли
  # увести из «Готово» или выдать по ней подменку. Тогда оплата всё равно
  # записана, а причина незакрытия остаётся на расчёте.
  class RegisterCheckPayment
    # 1С может присылать вид оплаты по-русски; словарь приводит его к
    # Payment::KINDS, на которых стоит вся отчётность Айса.
    PAYMENT_KINDS = {
      'наличные' => 'cash', 'наличными' => 'cash', 'карта' => 'card', 'картой' => 'card',
      'кредит' => 'credit', 'рассрочка' => 'credit', 'сертификат' => 'certificate',
      'трейд-ин' => 'trade_in', 'трейдин' => 'trade_in', 'qr' => 'qr',
      'сбп' => 'qr', 'счёт' => 'invoice', 'счет' => 'invoice'
    }.freeze

    attr_reader :checkout, :attributes

    def initialize(checkout:, attributes:)
      @checkout = checkout
      @attributes = attributes
    end

    def self.call(checkout:, attributes:)
      new(checkout: checkout, attributes: attributes).call
    end

    def call
      # Повторный колбэк по тому же чеку не должен второй раз архивировать
      # работу и второй раз просить отзыв.
      return current_state if checkout.settled?

      record_payment
      archive_service_job
      current_state
    end

    private

    def service_job
      checkout.service_job
    end

    def record_payment
      checkout.update!(state: :paid,
                       paid_at: parsed_time(attributes['paid_at']) || Time.current,
                       paid_total: attributes['total'],
                       check_number: attributes['check_number'].presence || checkout.check_number,
                       check_guid: attributes['check_guid'].presence || checkout.check_guid,
                       payments: normalized_payments,
                       cashier_name: attributes['cashier'],
                       last_error: nil)
    end

    def archive_service_job
      CloseCheckout.call(checkout: checkout)
    end

    def normalized_payments
      Array(attributes['payments']).map do |payment|
        kind = payment['kind'].to_s.strip
        { 'kind' => PAYMENT_KINDS[kind.downcase] || kind,
          'sum' => payment['sum'],
          'bank' => payment['bank'] }.compact
      end
    end

    def parsed_time(value)
      Time.zone.parse(value.to_s)
    rescue ArgumentError
      nil
    end

    def current_state
      { archived: checkout.reload.archived?, reason: checkout.not_archived_reason }
    end
  end
end
