# frozen_string_literal: true

class DeviceUnlockRequest < ApplicationRecord
  belongs_to :client
  belongs_to :item
  belongs_to :user
  belongs_to :department

  # «Комментарий последний» в таблице — полиморфный тред Comment (план §2.3),
  # тот же механизм, что у order/client/quick_order. Уведомления НЕ потянутся:
  # CommentsController#create_notifications шлёт их только если commentable
  # отвечает на :notification_recipients — у нас такого метода нет (план §2.4).
  has_many :comments, as: :commentable, dependent: :destroy

  # Кастомная история проекта (иконка часов) читает HistoryRecord, который
  # наполняет HistoryObserver — ОТДЕЛЬНАЯ система от гема `audited` ниже.
  # Без этой связи history-экшен и shared/show_history не работают.
  has_many :history_records, as: :object, dependent: :destroy

  audited

  # Workflow-статус по ТЗ: Новый → В работе → Требует согласования →
  # Согласован → Отказ от клиента. Цвет строки/бейджа в таблице (Цикл 2).
  enum status: {
    new_request:     0,
    in_progress:     1,
    needs_approval:  2,
    approved:        3,
    client_declined: 4
  }

  scope :recent, -> { order(created_at: :desc) }

  # Архивация (Цикл 8) — паттерн kanban-досок: boolean-колонка + явные scope'ы.
  # БЕЗ default_scope, чтобы show/archived_requests могли загрузить архивный
  # запрос. Имя scope :archived совпадает с колонкой — Rails разрешает.
  scope :active,   -> { where(archived: false) }
  scope :archived, -> { where(archived: true) }

  def last_comment
    comments.newest.first
  end

  def archive!
    update!(archived: true)
  end

  def unarchive!
    update!(archived: false)
  end
end
