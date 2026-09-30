# frozen_string_literal: true

# Приёмщик в новой приёмке обошёл справочник причин ремонта: разово выбрал вид ремонта
# (у продукта он в справочнике неверный или не задан) или вписал причины вручную.
# Суперадминам — чтобы поправить справочник. Одно уведомление на работу, даже если
# так заполнено несколько задач.
class RepairCatalogBypassNotifier
  KIND = 'repair_catalog_bypass'

  def self.call(service_job:, user:)
    new(service_job: service_job, user: user).call
  end

  def initialize(service_job:, user:)
    @service_job = service_job
    @user = user
  end

  def call
    return if details.empty?

    User.superadmins.active.find_each do |recipient|
      NotificationDispatcher.call(
        user: recipient,
        type_key: KIND,
        kind: KIND,
        message: message,
        url: url_helpers.service_job_path(service_job),
        referenceable: service_job
      )
    end
  end

  private

  attr_reader :service_job, :user

  def message
    I18n.t('notifications.repair_catalog_bypass',
           ticket: service_job.ticket_number,
           device: service_job.type_name,
           short_name: user.short_name,
           details: details.join('; '))
  end

  def details
    @details ||= [chosen_group_detail, manual_detail].compact
  end

  def chosen_group_detail
    ids = tasks.map(&:chosen_repair_group_id).reject(&:blank?).uniq
    return if ids.empty?

    chosen = RepairGroup.where(id: ids).pluck(:name).map { |name| "«#{name}»" }.join(', ')
    I18n.t('notifications.repair_catalog_bypass_group', chosen: chosen, catalog: catalog_group_name)
  end

  def manual_detail
    return unless tasks.any?(&:repair_causes_filled_manually?)

    I18n.t('notifications.repair_catalog_bypass_manual', text: service_job.claimed_defect.to_s.truncate(200))
  end

  def catalog_group_name
    name = service_job.item&.product_group&.repair_group&.name
    name ? "«#{name}»" : I18n.t('notifications.repair_catalog_bypass_not_set')
  end

  def tasks
    service_job.device_tasks.reject(&:marked_for_destruction?)
  end

  def url_helpers
    Rails.application.routes.url_helpers
  end
end
