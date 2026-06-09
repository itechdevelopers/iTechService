# frozen_string_literal: true

# Управление рассылками — только суперадмин (как и управление Telegram-чатами,
# см. TelegramBotSettingPolicy#manage_chats?).
class TelegramBroadcastPolicy < ApplicationPolicy
  def index?
    superadmin?
  end

  def new?
    superadmin?
  end

  def create?
    superadmin?
  end

  def edit?
    superadmin?
  end

  def update?
    superadmin?
  end

  def destroy?
    superadmin?
  end

  def send_now?
    superadmin?
  end
end
