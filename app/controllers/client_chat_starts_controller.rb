# frozen_string_literal: true

# Написать человеку первым. Модалка в два шага: кто (номер или клиент из
# базы) → где человек доступен и что написать. Открывается из шапки «Диалогов
# с клиентами» — с пустым полем, и из карточки клиента — сразу со вторым
# шагом.
class ClientChatStartsController < ApplicationController
  before_action :authorize_start

  def new
    @client = find_client
    @reach = ClientChat::Reachability.call(client: @client) if @client
    render 'shared/show_modal_form'
  end

  # Подсказки клиентов по мере набора имени или номера. Номера в карточках
  # записаны как попало («+7 (914) 012-34-56»), и подстрока набранных цифр в
  # таком виде не находится — поэтому цифры сравниваем с одними цифрами
  # номера. Ведущие 7 и 8 отбрасываем: одни пишут номер с 8, другие с +7.
  def clients
    digits = params[:q].to_s.gsub(/\D/, '').sub(/\A[78](?=\d{3})/, '')
    scope = policy_scope(Client)
    scope = if digits.length >= 4
              scope.where("regexp_replace(clients.full_phone_number, '[^0-9]', '', 'g') LIKE ?", "%#{digits}%")
            else
              scope.search(client_q: params[:q])
            end
    @clients = scope.limit(10)
  end

  # Проверка идёт только по кнопке, а не на каждую набранную цифру: каждая —
  # обращение к мессенджерам, за частые обращения они ограничивают аккаунт.
  def check
    @client = find_client
    @phone_input = params[:phone].to_s.strip
    if @client || ClientChat::Phone.normalize(@phone_input)
      @reach = ClientChat::Reachability.call(client: @client, phone: @phone_input)
    else
      @who_error = true
    end
    render :refresh
  end

  def create
    @client = find_client
    channel = params[:channel].to_s
    if ClientConversation::CHANNELS.include?(channel)
      @result = ClientChat::StartConversation.call(channel: channel, client: @client, phone: params[:phone],
                                                   user: current_user, body: params[:body])
      return if @result.success?
    end

    # Модалку показываем заново с тем же текстом — набранное не должно
    # пропасть из-за того, что, например, кончился суточный лимит.
    @body = params[:body]
    @selected = channel
    @reach = ClientChat::Reachability.call(client: @client, phone: params[:phone])
  end

  private

  def authorize_start
    authorize ClientConversation, :start?
  end

  def find_client
    policy_scope(Client).find(params[:client_id]) if params[:client_id].present?
  end
end
