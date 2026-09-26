# frozen_string_literal: true

module ServiceJobs
  # Закрытие работы по оплаченному расчёту: одна и та же процедура для оплаты,
  # пришедшей из 1С, и для чека, пробитого вручную при обрыве связи.
  class CloseCheckout
    attr_reader :checkout

    def initialize(checkout:)
      @checkout = checkout
    end

    def self.call(checkout:)
      new(checkout: checkout).call
    end

    def call
      as_initiator do
        if service_job.archive
          checkout.update!(state: :archived, archived_at: Time.current, not_archived_reason: nil)
          request_review
          true
        else
          checkout.update!(not_archived_reason: service_job.errors.full_messages.to_sentence)
          false
        end
      end
    end

    private

    def service_job
      checkout.service_job
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
  end
end
