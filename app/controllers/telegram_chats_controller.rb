# frozen_string_literal: true

class TelegramChatsController < ApplicationController
  before_action :set_telegram_chat, only: %i[edit update destroy]

  def new
    authorize :telegram_bot_setting, :create_chat?
    @telegram_chat = TelegramChat.new
    render 'shared/show_modal_form'
  end

  def create
    authorize :telegram_bot_setting, :create_chat?
    @telegram_chat = TelegramChat.new(telegram_chat_params)
    @telegram_chat.save
    load_chats
  end

  def edit
    authorize :telegram_bot_setting, :update_chat?
    @telegram_chat = TelegramChat.find(params[:id])
    render 'shared/show_modal_form'
  end

  def update
    authorize :telegram_bot_setting, :update_chat?
    @telegram_chat.update(telegram_chat_params)
    load_chats
  end

  def destroy
    authorize :telegram_bot_setting, :destroy_chat?
    @telegram_chat.destroy
    load_chats
  end

  private

  def set_telegram_chat
    @telegram_chat = TelegramChat.find(params[:id])
  end

  def load_chats
    @telegram_chats = TelegramChat.order(:name)
  end

  def telegram_chat_params
    params.require(:telegram_chat).permit(:name, :chat_id)
  end
end
