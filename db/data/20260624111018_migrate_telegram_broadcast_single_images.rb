# frozen_string_literal: true

# Переносит одиночную картинку каждой рассылки (старая колонка `image`)
# в новую коллекцию telegram_broadcast_images. Колонку `image` дропаем
# отдельной schema-миграцией позже, поэтому здесь она ещё доступна.
class MigrateTelegramBroadcastSingleImages < ActiveRecord::Migration[5.1]
  def up
    TelegramBroadcast.where.not(image: [nil, '']).find_each do |broadcast|
      next if broadcast.images.exists? # идемпотентность: уже перенесли

      uploaded = broadcast.image
      next unless uploaded.file&.exists?

      # Перезаписываем файл через CarrierWave — у нового аплоадера другой
      # store_dir, простого копирования строки имени файла недостаточно.
      image = broadcast.images.build
      File.open(uploaded.path) { |io| image.file = io }
      image.save!
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
