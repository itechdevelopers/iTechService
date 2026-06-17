# frozen_string_literal: true

# Асинхронная проверка факта покупки устройства в 1С по серийнику запроса.
# Структура скопирована с DetectSoldByUsJob (тот же endpoint StatusID).
#
# Результат — отдельное измерение purchase_check_status (НЕ workflow-статус):
#   «Продан» + дата → confirmed (+ sold_at);
#   любой другой ответ 1С (Принят/Списан/Не найден) → unconfirmed;
#   1С недоступна (success: false) → unconfirmed с текстом ошибки.
# В каждом исходе шлём цветное уведомление получателям (см. ClientRequestNotifier).
#
# retry_on оставлен для НЕПРЕДВИДЕННЫХ исключений (например, сбой БД при update).
# Штатная недоступность 1С приходит как success: false и обрабатывается БЕЗ
# raise — иначе на каждой повторной попытке слалось бы дублирующее уведомление.
class CheckClientRequestPurchaseJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(client_request_id)
    request = ClientRequest.find_by(id: client_request_id)
    return unless request
    return if request.confirmed?

    serial = request.item&.serial_number
    if serial.blank?
      mark_unconfirmed(request, 'У устройства не указан серийный номер')
      return
    end

    result = DeviceStatusService.new.check_status_data(serial)

    if result[:success] && result[:status] == 'Продан' && result[:sold_at].present?
      request.update!(
        sold_at: result[:sold_at].to_date,
        purchase_check_status: :confirmed,
        purchase_checked_at: Time.zone.now,
        purchase_check_error: nil
      )
      ClientRequestNotifier.notify_confirmed(request)
    elsif result[:success]
      mark_unconfirmed(request, "1С: статус устройства «#{result[:status]}»")
    else
      mark_unconfirmed(request, result[:error])
    end
  end

  private

  def mark_unconfirmed(request, error)
    request.update!(
      purchase_check_status: :unconfirmed,
      purchase_checked_at: Time.zone.now,
      purchase_check_error: error
    )
    ClientRequestNotifier.notify_unconfirmed(request)
  end
end
