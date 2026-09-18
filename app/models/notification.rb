class Notification < ApplicationRecord
  # Хардкод-список типов для фильтрации в модалке «Все уведомления».
  # При добавлении новой сущности в referenceable — добавить сюда же.
  # См. docs/notifications-implementation-guide.md, раздел «Filter chips».
  TYPE_LABELS = {
    'ServiceJob'               => 'Ремонты',
    'Order'                    => 'Заказы',
    'WaitingClient'            => 'Очередь клиентов',
    'DeviceNote'               => 'Заметки к устройству',
    'OrderNote'                => 'Заметки по заказу',
    'Comment'                  => 'Комментарии',
    'Message'                  => 'Сообщения',
    'CallTranscription'        => 'Транскрипции звонков',
    'UserAchievement'          => 'Достижения',
    'Kanban::Card'             => 'Канбан-карточки',
    'Kanban::Column'           => 'Канбан-колонки',
    'GlassStickingNotification' => 'Стикеры стекла',
    'TestingSession'           => 'Тестирование',
    'ApprovalRequest'          => 'Согласования',
    'ClientRequest'            => 'Запросы клиентов',
    'DeviceUnlockRequest'      => 'Запросы на разблокировку',
    'GisReview'                => 'Отзывы 2ГИС',
    'ReviewSourceAlert'        => 'Сбои сбора отзывов',
    'Inventory'                => 'Ревизии',
    'Merit'                    => 'Плюсы',
    'Fault'                    => 'Минусы',
    'ClientConversation'       => 'Диалоги с клиентами',
    nil                        => 'Без типа'
  }.freeze

  belongs_to :user
  belongs_to :referenceable, polymorphic: true, optional: true

  scope :not_closed,         -> { where(closed_at: nil) }
  # Скрытая запись создаётся, когда сотрудник отключил себе колокольчик по
  # этому типу: в поповер и модалку она не идёт, но остаётся в журнале, держит
  # защиту от дублей (Notification.exists?) и даёт повторам точку остановки.
  scope :visible,            -> { where(hidden_at: nil) }
  scope :of_type,            ->(type_key) { where(type_key: type_key) }

  validates :user_id, :message, presence: true

  def close
    update(closed_at: Time.zone.now)
  end

  def closed?
    closed_at.present?
  end

  def hidden?
    hidden_at.present?
  end
end