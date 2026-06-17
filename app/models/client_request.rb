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

  # Срок использования = период от продажи (1С) до создания запроса.
  # В БД не хранится — считается на лету (план §3).
  def usage_duration
    return if sold_at.blank?

    (created_at.to_date - sold_at).to_i.days
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
end
