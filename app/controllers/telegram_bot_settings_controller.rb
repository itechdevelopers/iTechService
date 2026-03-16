# frozen_string_literal: true

class TelegramBotSettingsController < ApplicationController
  def index
    authorize :telegram_bot_setting
    @telegram_chats = TelegramChat.order(:name)
  end
end
