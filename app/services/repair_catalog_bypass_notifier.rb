# frozen_string_literal: true

require 'cgi'

# Приёмщик в новой приёмке обошёл справочник причин ремонта: разово выбрал вид ремонта
# (у продукта он в справочнике неверный или не задан) или вписал причины вручную.
# Суперадминам и обладателям права — чтобы поправить справочник. Одно уведомление
# на работу, даже если так заполнено несколько задач.
#
# Названия видов ремонта в тексте обёрнуты в **…**: колокольчик и Telegram рисуют их
# жирными (см. .html), а в базе остаётся простой текст.
class RepairCatalogBypassNotifier
  KIND = 'repair_catalog_bypass'
  ABILITY = 'receive_repair_catalog_bypass_notifications'

  def self.call(service_job:, user:)
    new(service_job: service_job, user: user).call
  end

  # uniq — у суперадмина может стоять и галочка права.
  def self.recipients
    (User.superadmins.active.to_a + User.active.with_ability(ABILITY).to_a).uniq
  end

  # Экранируем до замены маркеров: вписанные приёмщиком причины не должны стать разметкой.
  def self.html(message)
    CGI.escapeHTML(message.to_s).gsub(/\*\*(.+?)\*\*/, '<b>\1</b>')
  end

  def initialize(service_job:, user:)
    @service_job = service_job
    @user = user
  end

  def call
    return if details.empty?

    self.class.recipients.each do |recipient|
      NotificationDispatcher.call(
        user: recipient,
        type_key: KIND,
        kind: KIND,
        message: message,
        url: url_helpers.service_job_path(service_job),
        referenceable: service_job,
        telegram_text: -> { telegram_text }
      )
    end
  end

  private

  attr_reader :service_job, :user

  def message
    @message ||= I18n.t('notifications.repair_catalog_bypass',
                        ticket: service_job.ticket_number,
                        device: service_job.type_name,
                        short_name: user.short_name,
                        details: details.join('; '))
  end

  def telegram_text
    @telegram_text ||= begin
      sj_url = url_helpers.service_job_url(service_job, host: app_host)
      [self.class.html(message), %(<a href="#{sj_url}">#{NotificationDispatcher::LINK_LABEL}</a>)].join("\n\n")
    end
  end

  def details
    @details ||= [chosen_group_detail, manual_detail].compact
  end

  # В выборе вида ремонта есть и справочный: если приёмщик выбрал его же,
  # справочник он не обходил.
  def chosen_group_detail
    ids = tasks.map(&:chosen_repair_group_id).reject(&:blank?).map(&:to_i).uniq - [catalog_group&.id]
    return if ids.empty?

    chosen = RepairGroup.where(id: ids).pluck(:name).map { |name| bold(name) }.join(', ')
    return I18n.t('notifications.repair_catalog_bypass_group_not_set', chosen: chosen) if catalog_group.nil?

    I18n.t('notifications.repair_catalog_bypass_group', catalog: bold(catalog_group.name), chosen: chosen)
  end

  # Выбранные из справочника причины называем отдельно: в заявленном дефекте они
  # склеены с вписанными, и не понять, какие откуда.
  def manual_detail
    manual_tasks = tasks.select(&:repair_causes_filled_manually?)
    return if manual_tasks.empty?

    text = manual_text(manual_tasks)
    picked = tasks.flat_map { |task| task.expected_repair_causes.map(&:title) }.uniq
    return I18n.t('notifications.repair_catalog_bypass_manual', text: text) if picked.empty?

    I18n.t('notifications.repair_catalog_bypass_mixed',
           text: text, picked: picked.map { |title| "«#{title}»" }.join(', '))
  end

  # Отметку можно поставить, ничего не вписав, — тогда показываем заявленный дефект:
  # по нему видно хотя бы, с чем пришёл клиент.
  def manual_text(manual_tasks)
    text = manual_tasks.map { |task| task.manual_repair_causes.to_s.strip }.reject(&:blank?).join('; ')
    (text.presence || service_job.claimed_defect).to_s.truncate(200)
  end

  def catalog_group
    return @catalog_group if defined?(@catalog_group)

    @catalog_group = service_job.item&.product_group&.repair_group
  end

  def bold(text)
    "**#{text}**"
  end

  def tasks
    service_job.device_tasks.reject(&:marked_for_destruction?)
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
