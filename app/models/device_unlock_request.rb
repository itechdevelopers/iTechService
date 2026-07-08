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

  # Запомненные получатели уведомлений (план §11 → расширение). Заполняется в
  # пикере при переходе «на согласование» (notify_approval). После этого любая
  # активность по запросу (смена статуса, комментарии) уведомляет этот набор +
  # суперадминов. HABTM по образцу ServiceJob#subscribers. dependent: :destroy
  # чистит join-строки при удалении запроса (сами юзеры не трогаются).
  has_and_belongs_to_many :subscribers,
                          join_table: :device_unlock_request_subscriptions,
                          association_foreign_key: :subscriber_id,
                          class_name: 'User',
                          dependent: :destroy

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

  # Ярлыки статусов для ТЕКСТА уведомления (план §11) — намеренно отдельно от
  # локали `statuses.*` (там короткие бейджи «Согласован»): здесь падежная форма
  # под фразу «статус обновлён: …». Хардкод RU — уведомления только на русском.
  STATUS_NOTIFICATION_LABELS = {
    'needs_approval'  => 'на согласовании',
    'approved'        => 'согласован',
    'client_declined' => 'отказ клиента'
  }.freeze

  def last_comment
    comments.newest.first
  end

  # Рассылает персональный Notification + ActionCable-broadcast каждому получателю.
  # Получателей передаём аргументом. Автора действия НЕ исключаем ни в одном
  # уведомлении (решение заказчика 2026-07-09): если суперадмин сам меняет статус
  # или пишет комментарий — колокольчик приходит и ему тоже.
  def notify(recipients, message, url:)
    Array(recipients).uniq.each do |recipient|
      notification = Notification.create!(
        user: recipient,
        message: message,
        url: url,
        referenceable: self
      )
      UserNotificationChannel.broadcast_to(recipient, notification)
    end
  end

  # Ссылка ведёт на список (index_url), а не на сам запрос: новый всплывает
  # наверх по scope :recent. exclude_current_user не передаём, поэтому автор,
  # если он суперадмин, тоже попадает в получателей.
  def notify_about_creation
    notify(User.superadmins.active, creation_notification_message, url: index_url)
  end

  def creation_notification_message
    "Создан новый запрос на разблокировку: #{client.full_name}"
  end

  def index_url
    Rails.application.routes.url_helpers.device_unlock_requests_path
  end

  # Получатели уведомлений о любой активности после «на согласование»:
  # запомненные подписчики + суперадмины (дедуп в #notify). Автор не исключается.
  def activity_recipients
    subscribers.to_a + User.superadmins.active.to_a
  end

  # Уведомление о смене статуса. Гейт (решение заказчика 2026-07-09): рассылаем
  # ТОЛЬКО когда запрос уже проходил через пикер «на согласование» и подписчики
  # записаны. Пока подписчиков нет — смена статуса молчит (в т.ч. approved/
  # client_declined, достигнутые в обход пикера). Ссылка ведёт на сам запрос.
  def notify_status_change
    return if subscribers.empty?

    notify(activity_recipients, status_notification_message, url: show_url)
  end

  # Текст: статус + идентификация запроса (клиент + устройство), как в строке
  # таблицы (_device_unlock_request: item.name + серийник, client.short_name).
  def status_notification_message
    device = [item.name, item.serial_number].reject(&:blank?).join(' ')
    "По запросу на разблокировку статус обновлён: #{STATUS_NOTIFICATION_LABELS[status]}. " \
      "Клиент: #{client.short_name}, устройство: #{device}"
  end

  def show_url
    Rails.application.routes.url_helpers.device_unlock_request_path(self)
  end

  def archive!
    update!(archived: true)
  end

  def unarchive!
    update!(archived: false)
  end
end
