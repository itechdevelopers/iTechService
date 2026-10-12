# Лимит новых диалогов в WhatsApp за сутки работает и без этой строки (значение
# по умолчанию в ClientChat::StartConversation), но страница параметров
# показывает только существующие строки — без неё лимит было бы не найти.
class SeedClientChatWhatsappDailyStarts < ActiveRecord::Migration[5.1]
  NAME = 'client_chat_whatsapp_daily_starts'

  def up
    setting = Setting.find_or_initialize_by(name: NAME, department_id: nil)
    return if setting.persisted?

    setting.value = '10'
    setting.value_type = 'integer'
    setting.presentation = I18n.t("settings.#{NAME}")
    setting.save!
  end

  def down
    Setting.where(name: NAME, department_id: nil).delete_all
  end
end
