# frozen_string_literal: true

class TelegramBotSettingPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def manage_chats?
    superadmin?
  end

  def create_chat?
    manage_chats?
  end

  def update_chat?
    manage_chats?
  end

  def destroy_chat?
    manage_chats?
  end
end
