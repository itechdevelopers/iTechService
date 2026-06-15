# frozen_string_literal: true

# Поздравления с ДР — только суперадмин (как и управление Telegram-чатами
# и рассылками, см. TelegramBotSettingPolicy#manage_chats?, TelegramBroadcastPolicy).
class BirthdayGreetingPolicy < ApplicationPolicy
  def edit?
    superadmin?
  end

  def update?
    superadmin?
  end

  def send_now?
    superadmin?
  end
end
