# frozen_string_literal: true

module ServiceJobs
  # Чек пробили в 1С руками — связи не было, а клиента надо отпустить.
  # Сотрудник вводит номер чека, работа закрывается, а расчёт остаётся
  # неподтверждённым: сверка по номеру работы найдёт этот чек в 1С и покажет
  # его старшему на проверку.
  class RegisterManualCheck
    attr_reader :service_job, :user, :check_number

    def initialize(service_job:, user:, check_number:)
      @service_job = service_job
      @user = user
      @check_number = check_number.to_s.strip
    end

    def self.call(service_job:, user:, check_number:)
      new(service_job: service_job, user: user, check_number: check_number).call
    end

    def call
      recall_unfinished_checkout
      checkout = create_manual_checkout
      archived = CloseCheckout.call(checkout: checkout)

      { checkout: checkout, archived: archived, reason: checkout.reload.not_archived_reason }
    end

    private

    # Наш отложенный чек мог всё-таки уехать в 1С; кассир пробил другой, значит
    # этот надо убрать из РМК, иначе его рассчитают повторно.
    def recall_unfinished_checkout
      pending = service_job.current_checkout
      return if pending.nil? || !pending.cancellable?

      pending.update!(state: :cancelled,
                      cancelled_at: Time.current,
                      cancel_reason: "Заменён ручным переносом, чек № #{check_number}")
      CancelServiceCheckJob.perform_later(pending.id) if pending.sent?
    end

    def create_manual_checkout
      checkout = service_job.checkouts.new(initiator: user, manual: true)
      builder = CheckoutPayloadBuilder.new(checkout)
      # Фактическую сумму знает только 1С — её подставит сверка, а пока храним
      # ту, что мы бы отправили в чек.
      checkout.assign_attributes(state: :paid,
                                 check_number: check_number,
                                 paid_at: Time.current,
                                 expected_total: builder.total,
                                 items_snapshot: builder.items)
      checkout.save!
      checkout
    end
  end
end
