# frozen_string_literal: true

class TelegramChat < ApplicationRecord
  # Группа, куда бот дублирует события согласований. Название задаётся в
  # настройках Telegram-бота, поэтому ищем по вхождению: реальные группы часто
  # называют «🔧 Технарские уведомления» или «Технарские уведомления (Владивосток)».
  TECH_NOTIFICATIONS = 'технарские уведомления'

  validates :name, presence: true
  validates :chat_id, presence: true, uniqueness: true

  # Поиск ведём в Ruby, а НЕ через lower()/ILIKE в SQL: база создана с
  # collation C, где эти функции не сворачивают регистр кириллицы («Технарские»
  # так и останется не равным «технарские»). Чатов в таблице единицы, поэтому
  # полная выборка дешевле, чем возня с COLLATE, чьё имя ещё и различается
  # на dev и проде (ru_RU.UTF-8 против ru_RU.utf8).
  def self.find_by_name_part(part)
    needle = normalize_name(part)
    return nil if needle.blank?

    all.detect { |chat| normalize_name(chat.name).include?(needle) }
  end

  def self.tech_notifications
    find_by_name_part(TECH_NOTIFICATIONS)
  end

  # Регистр + любые пробельные вольности («Технарские  уведомления») не должны
  # мешать совпадению.
  def self.normalize_name(value)
    value.to_s.downcase.gsub(/\s+/, ' ').strip
  end
end
