# frozen_string_literal: true

# Написать клиенту первым в мессенджере GREEN-API — из его карточки. Модалка
# сначала показывает, нашёлся ли номер в мессенджере (и, если мессенджер это
# сообщает, как человек там подписан), и только потом даёт отправить
# сообщение. Канал приходит из маршрута: /clients/:id/max_chat или
# /clients/:id/whatsapp_chat.
class ClientChatStartsController < ApplicationController
  before_action :set_channel

  def new
    authorize ClientConversation, :start?
    @client = find_client
    load_search
    render 'shared/show_modal_form'
  end

  def create
    authorize ClientConversation, :start?
    @client = find_client
    @result = ClientChat::StartConversation.call(channel: @channel.key, client: @client, user: current_user,
                                                 body: params[:body])
    return if @result.success?

    # Модалку показываем заново с тем же текстом — набранное не должно
    # пропасть из-за того, что, например, кончился суточный лимит.
    @body = params[:body]
    @search = @result.search
    load_search if @search.nil?
  end

  private

  def set_channel
    @channel = GreenApi::Channel.fetch(params[:channel])
  rescue KeyError
    raise ActiveRecord::RecordNotFound
  end

  def find_client
    policy_scope(Client).find(params[:client_id])
  end

  # При исчерпанном лимите в мессенджер не идём вовсе: проверка номера — тоже
  # обращение, за которое мессенджер может ограничить аккаунт.
  def load_search
    @limit_reached = ClientChat::StartConversation.limit_reached?(@channel.key)
    @search = @channel.account_search.call(@client.full_phone_number) unless @limit_reached
  end
end
