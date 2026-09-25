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
      as_initiator do
        if service_job.archive
          checkout.update!(state: :archived, archived_at: Time.current, not_archived_reason: nil)
          request_review
        else
          checkout.update!(not_archived_reason: service_job.errors.full_messages.to_sentence)
        end
      end
    end

    def request_review
      return if Review.exists?(service_job: service_job)

      ServiceJobs::MakeReview.call(service_job: service_job, user: checkout.initiator)
    end

    # Архив пишется в историю и проверяется правами, а User.current в запросе от
    # 1С — машинный пользователь. Подставляем того, кто отправил чек, и кладём
    # прежнее значение обратно: User.current — это cattr, общий на весь процесс.
    def as_initiator
      return yield if checkout.initiator.nil?

      previous = User.current
      User.current = checkout.initiator
      begin
        yield
      ensure
        User.current = previous
      end
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
