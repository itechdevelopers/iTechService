# frozen_string_literal: true

require 'cgi'

# Сообщает сотруднику, что ему выставили плюс (Merit) или минус (Fault).
# Два канала: колокольчик «айса» (Notification + ActionCable-broadcast) и
# личка в Telegram (через NotifyEmployeeJob — незалинкованные молча
# пропускаются, доставка уходит из веб-запроса в фон).
#
#   MeritFaultNotifier.call(merit)
#
# Вызывается из Merit::Create / Fault::Create, то есть только для выставленных
# руками записей. Автоминус за отсутствие фото при приёмке создаётся мимо
# операции (ServiceJob#issue_reception_photo_fault!) и рассылает собственное
# уведомление внутри ReceptionPhotoCheckJob — задвоения не будет.
class MeritFaultNotifier
  KINDS = { 'Merit' => 'merit_issued', 'Fault' => 'fault_issued' }.freeze

  def self.call(record)
    new(record).call
  end

  def initialize(record)
    @record = record
  end

  def call
    return if recipient.nil?

    create_bell
    NotifyEmployeeJob.perform_later(recipient.id, telegram_text)
  end

  private

  attr_reader :record

  def merit?
    record.is_a?(Merit)
  end

  # У плюса получатель — recipient, у минуса — causer.
  def recipient
    @recipient ||= merit? ? record.recipient : record.causer
  end

  def create_bell
    notification = Notification.create!(
      user: recipient,
      message: bell_text,
      url: profile_path,
      referenceable: record,
      kind: KINDS[record.class.name]
    )
    UserNotificationChannel.broadcast_to(recipient, notification)
  end

  def bell_text
    I18n.t("#{scope}.bell#{penalty_suffix}", interpolations)
  end

  # parse_mode HTML в SendTelegramMessage → свободный текст (комментарий, имя
  # выдавшего, название вида минуса) экранируем.
  def telegram_text
    I18n.t("#{scope}.telegram#{penalty_suffix}", escaped_interpolations.merge(url: profile_url))
  end

  def scope
    merit? ? 'merit_notification' : 'fault_notification'
  end

  # У финансовых видов минуса ступень штрафа не считается (penalty остаётся
  # пустым), поэтому для них берём вариант текста без строки о штрафе.
  def penalty_suffix
    return '' if merit? || record.penalty.blank?

    '_with_penalty'
  end

  def interpolations
    values = { issuer: issuer_name, comment: record.comment.to_s }
    values.merge!(kind: record.name.to_s, penalty: record.penalty) unless merit?
    values
  end

  def escaped_interpolations
    interpolations.each_with_object({}) do |(key, value), result|
      result[key] = value.is_a?(String) ? CGI.escapeHTML(value) : value
    end
  end

  # issued_by заполняется формой, но в старых записях бывает пустым — без
  # запасного значения текст вырождается в «от .».
  def issuer_name
    record.issued_by&.short_name.presence || '—'
  end

  def profile_path
    url_helpers.user_path(recipient)
  end

  def profile_url
    url_helpers.user_url(recipient, host: app_host)
  end

  def app_host
    ENV['SERVER_HOST'].presence ||
      Rails.application.routes.default_url_options[:host].presence ||
      'localhost:3000'
  end

  def url_helpers
    Rails.application.routes.url_helpers
  end
end
