class TelegramBroadcastImage < ApplicationRecord
  belongs_to :broadcast, class_name: 'TelegramBroadcast',
                         foreign_key: 'telegram_broadcast_id', inverse_of: :images

  mount_uploader :file, TelegramBroadcastImageUploader

  validates :file, presence: true
end
