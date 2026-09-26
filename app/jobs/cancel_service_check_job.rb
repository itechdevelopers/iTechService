# frozen_string_literal: true

# Отзыв отложенного чека. Локально расчёт уже отменён — работа разблокирована
# сразу, не дожидаясь ответа 1С. Если удалить чек не вышло, он остался висеть
# в РМК, и об этом должно остаться письменное свидетельство.
class CancelServiceCheckJob < ApplicationJob
  queue_as :default

  def perform(checkout_id)
    checkout = ServiceJobCheckout.find(checkout_id)
    result = ServiceCheckClient.new.delete_check(checkout.uid)
    data = result[:data].is_a?(Hash) ? result[:data] : {}

    return if result[:success] && data['Executed'] != false

    message = data['Error'].presence || result[:error].presence || 'Неизвестная ошибка 1С'
    checkout.update!(last_error: message)
    Rails.logger.warn "[ServiceCheck] Checkout #{checkout.id} not deleted in 1C: #{message}"
  end
end
