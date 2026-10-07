# frozen_string_literal: true

# Написать клиенту в MAX первым — из его карточки. Модалка сначала
# показывает, нашёлся ли номер в MAX и как человек там подписан, и только
# потом даёт отправить сообщение.
class ClientMaxChatsController < ApplicationController
  def new
    authorize ClientConversation, :start?
    @client = find_client
    load_search
    render 'shared/show_modal_form'
  end

  def create
    authorize ClientConversation, :start?
    @client = find_client
    @result = ClientChat::StartConversation.call(client: @client, user: current_user, body: params[:body])
    return if @result.success?

    # Модалку показываем заново с тем же текстом — набранное не должно
    # пропасть из-за того, что, например, кончился суточный лимит.
    @body = params[:body]
    @search = @result.search
    load_search if @search.nil?
  end

  private

  def find_client
    policy_scope(Client).find(params[:client_id])
  end

  # При исчерпанном лимите в MAX не идём вовсе: проверка номера — тоже
  # обращение, за которое MAX может ограничить аккаунт.
  def load_search
    @limit_reached = ClientChat::StartConversation.limit_reached?
    @search = MaxPhoneAccountSearch.call(@client.full_phone_number) unless @limit_reached
  end
end
