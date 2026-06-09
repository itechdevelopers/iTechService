class TelegramBroadcastVariant < ApplicationRecord
  belongs_to :broadcast, class_name: 'TelegramBroadcast',
                         foreign_key: 'telegram_broadcast_id', inverse_of: :variants

  validates :body, presence: true
end
