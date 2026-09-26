# frozen_string_literal: true

module ServiceJobs
  # Возврат чека в 1С. Деньги вернулись клиенту, значит работа снова не
  # оплачена: возвращаем её из архива и помечаем, что с запчастями надо
  # разобраться руками — вернуть их на склад автоматически нельзя, запчасть
  # может остаться в устройстве.
  class RegisterCheckCancellation
    attr_reader :checkout, :attributes

    def initialize(checkout:, attributes:)
      @checkout = checkout
      @attributes = attributes
    end

    def self.call(checkout:, attributes:)
      new(checkout: checkout, attributes: attributes).call
    end

    def call
      return { returned: false, reason: nil } if checkout.cancelled?

      returned = return_from_archive
      checkout.update!(state: :cancelled,
                       cancelled_at: parsed_time(attributes['cancelled_at']) || Time.current,
                       cancel_reason: cancel_reason,
                       parts_review_required: had_repair_parts?,
                       not_archived_reason: nil)

      { returned: returned, reason: @failure_reason }
    end

    private

    def service_job
      checkout.service_job
    end

    def cancel_reason
      [attributes['reason'].presence, return_check_label].compact.join('. ')
    end

    def return_check_label
      number = attributes['return_check_number'].presence
      "Чек возврата № #{number}" if number
    end

    def return_from_archive
      return false unless service_job.in_archive?

      target = service_job.department.locations.done.first
      if target.nil?
        @failure_reason = 'В отделе нет локации «Готово»'
        return false
      end

      service_job.system_archive_return = true
      return true if service_job.update(location: target)

      @failure_reason = service_job.errors.full_messages.to_sentence
      false
    ensure
      service_job.system_archive_return = false
    end

    def had_repair_parts?
      service_job.repair_parts.any?
    end

    def parsed_time(value)
      Time.zone.parse(value.to_s)
    rescue ArgumentError
      nil
    end
  end
end
