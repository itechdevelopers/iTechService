# frozen_string_literal: true

# Написать человеку первым. Модалка в два шага: кто (номер, клиент из базы
# или запись «Адресной книжки» телефонии) → где человек доступен и что
# написать. Открывается из шапки «Диалогов с клиентами» — с пустым полем, и
# из карточки клиента — сразу со вторым шагом.
class ClientChatStartsController < ApplicationController
  before_action :authorize_start
  helper_method :address_book_visible?

  def new
    @client = find_client
    @reach = ClientChat::Reachability.call(client: @client) if @client
    render 'shared/show_modal_form'
  end

  # Подсказки по мере набора имени или номера: клиенты и «Адресная книжка».
  # Номера в карточках клиентов записаны как попало («+7 (914) 012-34-56»), и
  # подстрока набранных цифр в таком виде не находится — поэтому цифры
  # сравниваем с одними цифрами номера. Ведущие 7 и 8 отбрасываем: одни пишут
  # номер с 8, другие с +7.
  def clients
    query = params[:q].to_s.strip
    digits = query.gsub(/\D/, '').sub(/\A[78](?=\d{3})/, '')
    scope = policy_scope(Client)
    scope = if digits.length >= 4
              scope.where("regexp_replace(clients.full_phone_number, '[^0-9]', '', 'g') LIKE ?", "%#{digits}%")
            else
              scope.search(client_q: query)
            end
    @clients = scope.limit(10)
    @labels = address_book_matches(query, digits)
  end

  # Проверка идёт только по кнопке, а не на каждую набранную цифру: каждая —
  # обращение к мессенджерам, за частые обращения они ограничивают аккаунт.
  def check
    @client = find_client
    @label = find_label
    @phone_input = params[:phone].to_s.strip.presence || @label&.phone_number.to_s
    if @client || ClientChat::Phone.normalize(@phone_input)
      @reach = ClientChat::Reachability.call(client: @client, phone: @phone_input)
    else
      @who_error = true
    end
    render :refresh
  end

  def create
    @client = find_client
    @label = find_label
    channel = params[:channel].to_s
    if ClientConversation::CHANNELS.include?(channel)
      @result = ClientChat::StartConversation.call(channel: channel, client: @client, phone: params[:phone],
                                                   name: @label&.label, user: current_user, body: params[:body])
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

  # «Адресная книжка» — служебные номера (филиалы, сотрудники, партнёры), и
  # видна она тем же, кому открыт «Справочник номеров» телефонии.
  def address_book_visible?
    policy(:telephony_directory).index?
  end

  def find_label
    PhoneLabel.find_by(id: params[:label_id]) if params[:label_id].present? && address_book_visible?
  end

  # Внутренние номера (3–4 цифры) мессенджеров не имеют — их не предлагаем.
  def address_book_matches(query, digits)
    return PhoneLabel.none unless address_book_visible?

    scope = PhoneLabel.where("phone_labels.phone_number ~ '^[0-9]{11,12}$'")
    scope = if digits.length >= 4
              scope.where('phone_labels.phone_number LIKE ?', "%#{digits}%")
            elsif query.length >= 2
              scope.where('LOWER(phone_labels.label) LIKE :q OR LOWER(phone_labels.group_name) LIKE :q',
                          q: "%#{query.mb_chars.downcase}%")
            else
              scope.none
            end
    scope.order(:label).limit(10)
  end
end
