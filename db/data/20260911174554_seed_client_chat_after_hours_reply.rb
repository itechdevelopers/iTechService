# frozen_string_literal: true

class SeedClientChatAfterHoursReply < ActiveRecord::Migration[5.1]
  # Текст автоответа клиенту, написавшему вне рабочих часов. Заводим запись
  # сразу, чтобы на /settings было видно и что за параметр, и какой текст
  # уходит — в коде остаётся такой же запасной вариант на случай, если
  # значение сотрут.
  #
  # %{hours} подставляется расписанием филиала диалога.
  def up
    setting = Setting.find_or_initialize_by(name: 'client_chat_after_hours_reply',
                                            department_id: nil)
    return if setting.persisted?

    setting.value = ClientChat::AutoReply::DEFAULT_TEXT
    setting.value_type = 'text'
    setting.presentation = I18n.t('settings.client_chat_after_hours_reply')
    setting.save!
  end

  def down
    Setting.find_by(name: 'client_chat_after_hours_reply', department_id: nil)&.destroy
  end
end
