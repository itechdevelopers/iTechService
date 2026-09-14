# frozen_string_literal: true

# Одно сообщение в диалоге с клиентом — в любую сторону, включая служебные
# записи ленты («диалог взят в работу», «закрыт автоматически»), которые
# клиенту не уходят.
class ClientMessage < ApplicationRecord
  DIRECTIONS = %w[in out].freeze
  KINDS = %w[text photo system].freeze
  DELIVERY_STATUSES = %w[pending sent failed].freeze

  belongs_to :conversation, class_name: 'ClientConversation',
                            foreign_key: :client_conversation_id, inverse_of: :messages
  # Пусто у входящих и у автоответов бота — см. #from_employee?.
  belongs_to :user, optional: true

  # photo? принадлежит CarrierWave («файл приложен»). Признак вида сообщения
  # называется photo_kind? — иначе одно молча затирало бы другое, и валидация
  # ниже начала бы требовать скачанный файл там, где строка создаётся сразу,
  # а картинка приезжает фоновой джобой.
  mount_uploader :photo, ClientMessagePhotoUploader

  validates :direction, inclusion: { in: DIRECTIONS }
  validates :kind, inclusion: { in: KINDS }
  validates :delivery_status, inclusion: { in: DELIVERY_STATUSES }
  # Фото клиент присылает и без подписи, остальным сообщениям текст обязателен.
  validates :body, presence: true, unless: :photo_kind?

  scope :chronological, -> { order(:created_at) }
  scope :inbound, -> { where(direction: 'in') }
  scope :outbound, -> { where(direction: 'out') }
  scope :from_employees, -> { outbound.where.not(kind: 'system', user_id: nil) }

  after_create :register_in_conversation
  after_create :broadcast_to_feed

  def inbound?
    direction == 'in'
  end

  def outbound?
    direction == 'out'
  end

  def system?
    kind == 'system'
  end

  def photo_kind?
    kind == 'photo'
  end

  # Ответ живого сотрудника — в отличие от автоответа бота (kind: system,
  # user пуст). Время первого ответа считается только по таким сообщениям,
  # иначе робот «отвечал» бы за сотрудника и обнулял метрику.
  def from_employee?
    outbound? && !system? && user_id.present?
  end

  private

  def register_in_conversation
    conversation.register_message(self)
  end

  def broadcast_to_feed
    ClientConversationChannel.broadcast_message(self)
  end
end
