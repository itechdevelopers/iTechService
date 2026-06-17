# frozen_string_literal: true

class ClientRequest < ApplicationRecord
  belongs_to :client
  belongs_to :item
  belongs_to :user
  belongs_to :department

  audited

  # Тип запроса. Сейчас реализуем только receipt_search; device_unblock —
  # задел на будущее (форма/поля могут отличаться, см. план §8).
  enum kind: { receipt_search: 0, device_unblock: 1 }

  # Workflow-статус (цвет строки/бейджа в таблице).
  enum status: { new_request: 0, in_progress: 1, done: 2, failed: 3 }

  # Проверка факта покупки в 1С — ОТДЕЛЬНОЕ измерение от workflow-статуса
  # (зеркалим ServiceJob#one_c_device_check_status, см. CONTEXT §2.3).
  enum purchase_check_status: { pending: 0, confirmed: 1, unconfirmed: 2 }

  scope :recent, -> { order(created_at: :desc) }

  # Запросы, по которым покупка НЕ подтверждена и workflow ещё открыт
  # (не done/failed). По ним ежедневный ClientRequestPurchaseReminderJob
  # шлёт напоминание, пока покупку не подтвердят или запрос не закроют.
  # Статусы берём через statuses.values_at — where.not с символами enum'а
  # в Rails 5.1 ненадёжен, а int-значения безопасны.
  scope :awaiting_purchase_followup,
        -> { unconfirmed.where.not(status: statuses.values_at('done', 'failed')) }

  # Проверка покупки в 1С запускается асинхронно сразу после создания запроса.
  # after_commit (а не after_create) — чтобы джоба читала уже закоммиченную
  # запись (иначе в Sidekiq-воркере её ещё не видно). См. CONTEXT, Sidekiq.
  after_commit :schedule_purchase_check, on: :create

  # Получатели уведомлений о проверке покупки: суперадмины + сотрудники с
  # галочкой ability work_with_receipt_search_requests (план §5). active —
  # чтобы не слать уволенным (см. memory feedback_user_active_scope).
  # uniq — суперадмин может иметь и галочку (AR-объекты дедуплицируются по id).
  def self.notification_recipients
    (User.superadmins.active.to_a +
     User.active.joins(:abilities)
         .where(abilities: { name: 'work_with_receipt_search_requests' }).to_a).uniq
  end

  # Срок использования = период от продажи (1С) до создания запроса.
  # В БД не хранится — считается на лету (план §3).
  def usage_days
    return if sold_at.blank?

    (created_at.to_date - sold_at).to_i
  end

  def usage_duration
    usage_days&.days
  end

  # Корзина срока для окраски уведомления и строки таблицы.
  # :under_year (красный) / :one_to_two (оранжевый) / :over_two (чёрный).
  def usage_bucket
    return if sold_at.blank?

    months = (created_at.to_date - sold_at).to_i / 30
    case months
    when 0...12  then :under_year
    when 12...24 then :one_to_two
    else              :over_two
    end
  end

  private

  def schedule_purchase_check
    CheckClientRequestPurchaseJob.perform_later(id)
  end
end
