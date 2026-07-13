# frozen_string_literal: true

# Шлёт админам сигнал «пора дозаказать пакеты», когда остаток по строке
# опустился до порога. Два канала: личное сообщение в Telegram (через
# NotifyEmployeeJob — незалинкованные молча пропускаются) и внутренний
# колокольчик «айса» (Notification + ActionCable-broadcast).
class PackageLowStockNotifier
  include ActionView::Helpers::SanitizeHelper

  def self.call(stock)
    new(stock).call
  end

  def initialize(stock)
    @stock = stock
    @design = stock.package_design
  end

  def call
    recipients.each do |user|
      create_bell(user)
      NotifyEmployeeJob.perform_later(user.id, telegram_text)
    end
  end

  private

  attr_reader :stock, :design

  # Владелец/админы. active — чтобы не слать уволенным (memory
  # feedback_user_active_scope).
  def recipients
    User.active.any_admin
  end

  def create_bell(user)
    notification = Notification.create!(
      user: user, message: bell_text, url: inventory_url, referenceable: stock
    )
    UserNotificationChannel.broadcast_to(user, notification)
  end

  def bell_text
    I18n.t('package_low_stock.bell',
           design: design.name, size: stock.size,
           boxes: stock.boxes_count, threshold: stock.low_stock_threshold)
  end

  # parse_mode HTML в SendTelegramMessage → динамику (имя дизайна и свободный
  # текст размера) экранируем (memory про NotifyEmployee и HTML).
  def telegram_text
    I18n.t('package_low_stock.telegram',
           design: CGI.escapeHTML(design.name.to_s), size: CGI.escapeHTML(stock.size.to_s),
           boxes: stock.boxes_count, threshold: stock.low_stock_threshold)
  end

  def inventory_url
    Rails.application.routes.url_helpers.package_designs_path
  end
end
