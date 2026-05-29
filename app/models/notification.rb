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
    nil                        => 'Без типа'
  }.freeze

  # kind уведомления о склейке стекла (см. RepairGluingReminderJob).
  # Цвет иконки уведомлений в topbar зависит от наличия именно этого kind.
  GLUING_KIND = 'repair_gluing'.freeze

  belongs_to :user
  belongs_to :referenceable, polymorphic: true, optional: true

  scope :not_closed, -> { where(closed_at: nil) }
  scope :gluing,     -> { where(kind: GLUING_KIND) }
  # IS DISTINCT FROM, а не <>: в Postgres `kind <> 'repair_gluing'` отбросил бы
  # все строки с kind IS NULL (а это большинство «обычных» уведомлений).
  scope :non_gluing, -> { where('kind IS DISTINCT FROM ?', GLUING_KIND) }

  validates :user_id, :message, presence: true

  def close
    update(closed_at: Time.zone.now)
  end

  def closed?
    closed_at.present?
  end
end