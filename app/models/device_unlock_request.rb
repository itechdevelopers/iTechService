# frozen_string_literal: true

class DeviceUnlockRequest < ApplicationRecord
  belongs_to :client
  belongs_to :item
  belongs_to :user
  belongs_to :department

  # «Комментарий последний» в таблице — полиморфный тред Comment (план §2.3),
  # тот же механизм, что у order/client/quick_order. Комментарии тут идут своим
  # add_comment-экшеном, который МИНУЕТ CommentsController#create_notifications,
  # поэтому уведомлений о комментариях по-прежнему НЕТ. Уведомляем только о
  # СОЗДАНИИ запроса — событийно, в #create (см. notify_about_creation ниже).
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

  # Получатели уведомления о новом запросе — суперадмины (они курируют/согласуют
  # разблокировки). .active — чтобы не слать уволенным (memory feedback_user_active_scope).
  def self.notification_recipients
    User.superadmins.active.to_a
  end

  def notification_message
    "Создан новый запрос на разблокировку: #{client.full_name}"
  end

  # Колокольчик ведёт на список запросов — новый всплывает наверх (scope :recent).
  def url
    Rails.application.routes.url_helpers.device_unlock_requests_path
  end

  # Событийное уведомление при создании (паттерн GlassStickingController#notify):
  # создаём персональный Notification на каждого получателя + realtime-броадкаст.
  # Автора исключаем — он сам только что создал запрос. Вынесено в модель, чтобы
  # вызывалось и из контроллера, и из rails runner при ручном тестировании.
  def notify_about_creation
    message = notification_message
    self.class.notification_recipients.reject { |u| u.id == user_id }.each do |recipient|
      notification = Notification.create(user_id: recipient.id,
                                         message: message,
                                         url: url,
                                         referenceable: self)
      UserNotificationChannel.broadcast_to(notification.user, notification) unless notification.errors.any?
    end
  end

  def archive!
    update!(archived: true)
  end

  def unarchive!
    update!(archived: false)
  end
end
