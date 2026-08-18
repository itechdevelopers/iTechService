# frozen_string_literal: true

# Утренняя проверка живости внешнего сервиса 87imei, через который идёт
# проверка «Найти iPhone» при приёмке. Шлёт запрос с постоянным эталонным
# IMEI (ENV FIND_MY_HEALTHCHECK_IMEI): любой ответ ON/OFF означает, что сервис
# на связи. Если сервис ответить не смог — суперадминам приходит in-app
# уведомление, чтобы они решили, отключать ли обязательную проверку в
# «Прочее» → «Проверка Найти iPhone».
#
# Настройку сервиса джоб не трогает — только уведомляет.
#
# Результат в find_my_device_checks не пишется: та таблица — журнал проверок
# устройств клиентов (и требует user_id), служебные запросы её бы засорили.
class FindMyDeviceHealthCheckJob < ApplicationJob
  queue_as :default

  # Единичный сетевой сбой не повод будить суперадминов — прежде чем признать
  # сервис лежачим, пробуем второй раз.
  RETRY_DELAY = 30

  def perform
    imei = ENV['FIND_MY_HEALTHCHECK_IMEI']

    if imei.blank?
      Rails.logger.warn('[FindMyHealthCheck] FIND_MY_HEALTHCHECK_IMEI is not set; skipping')
      return
    end

    result = check(imei)

    unless result[:success]
      sleep(RETRY_DELAY)
      result = check(imei)
    end

    if result[:success]
      Rails.logger.info("[FindMyHealthCheck] OK: #{result[:raw_result]}")
      return
    end

    Rails.logger.error("[FindMyHealthCheck] FAILED: #{result[:error]}")
    notify_superadmins(result[:error])
  end

  private

  def check(imei)
    FindMyDeviceCheckService.call(imei: imei)
  end

  def notify_superadmins(error)
    recipients = User.active.superadmins
    Rails.logger.info("[FindMyHealthCheck] Notifying #{recipients.count} superadmins")

    path = Rails.application.routes.url_helpers.find_my_device_checks_path
    # Ошибка приходит из HTTParty/сети и бывает на несколько строк — суперадмину
    # нужна суть, полный текст остаётся в логе.
    reason = ActionController::Base.helpers.truncate(error.to_s, length: 120)

    recipients.each do |recipient|
      Notification.create!(
        user: recipient,
        message: "Сервис проверки «Найти iPhone» не отвечает (#{reason}). " \
                 "Проверка при приёмке сейчас не работает — " \
                 "<a href=\"#{path}\">отключить обязательную проверку</a>",
        url: path
      )
    end
  end
end
