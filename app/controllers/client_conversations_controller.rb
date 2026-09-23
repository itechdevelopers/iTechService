# frozen_string_literal: true

class ClientConversationsController < ApplicationController
  # Порядок определяет и порядок чипов на странице. По умолчанию открывается
  # «Без ответа» — это рабочая очередь, всё остальное справочное.
  FILTERS = %w[awaiting mine open closed].freeze
  PER_PAGE = 200

  def index
    authorize ClientConversation

    @filter = FILTERS.include?(params[:filter]) ? params[:filter] : FILTERS.first
    @cities = City.with_real_departments
    @counts = filter_counts
    @conversations = ordered(filtered_scope).includes(:client, :city, :assigned_user)
                                            .limit(PER_PAGE).to_a
    @last_messages = ClientConversation.last_messages_for(@conversations)
  end

  def show
    @conversation = find_record ClientConversation
    load_card
  end

  # Ответ клиенту. Сообщение сначала ложится в ленту со статусом pending и
  # только потом уходит джобом — сотрудник видит свою реплику сразу, а её
  # судьбу («не доставлено») узнаёт из той же строки.
  def reply
    @conversation = find_record ClientConversation
    body = reply_params[:body].to_s.strip

    photo = reply_params[:photo]
    assigned_before = @conversation.assigned_user_id

    if @conversation.closed?
      @error = t('.conversation_closed')
    elsif body.blank? && photo.blank?
      @error = t('.empty_body')
    else
      @message = @conversation.messages.create!(
        direction: 'out', kind: photo.present? ? 'photo' : 'text',
        body: body.presence, photo: photo,
        user: current_user, delivery_status: 'pending'
      )
      SendClientMessageJob.perform_later(@message.id)
    end

    # Ответ мог сделать сотрудника ответственным — тогда устарела и шапка
    # карточки, и набор кнопок, а не только лента.
    @assignment_changed = @conversation.assigned_user_id != assigned_before

    # jquery_ujs отменяет AJAX, если в форме выбран файл, и отправляет её
    # обычным способом — поэтому у экшена обязан быть HTML-ответ, иначе
    # отправка фото падала бы с ActionView::MissingTemplate.
    respond_to do |format|
      format.js do
        if @assignment_changed
          load_card
          render :update_card
        else
          render :reply
        end
      end
      format.html do
        flash[:alert] = @error if @error
        redirect_to client_conversation_path(@conversation)
      end
    end
  end

  # Взять в работу и перехватить — один экшен: разница только в том, был ли
  # диалог за кем-то, и её отражает запись в ленте.
  def assign
    @conversation = find_record ClientConversation
    @conversation.assign_to!(current_user)
    load_card
    render :update_card
  end

  def close
    @conversation = find_record ClientConversation
    @conversation.close!(current_user) if @conversation.open?
    load_card
    render :update_card
  end

  # Город правится вручную, когда клиент выбрал не тот или не выбрал вовсе.
  def change_city
    @conversation = find_record ClientConversation
    @conversation.change_city!(City.with_real_departments.find_by(id: params[:city_id]))
    load_card
    render :update_card
  end

  # Число диалогов без ответа для иконки в топбаре. Считается на сервере под
  # конкретного сотрудника: у каждого свой город.
  def counter
    authorize ClientConversation
    @awaiting_count = ClientConversation.awaiting_count_for(current_user)
  end

  # Поиск клиента для привязки. Общий пикер из формы приёмки переиспользовать
  # нельзя: он завязан на её разметку (#client_search, #service_job_client_id)
  # и на абсолютное позиционирование списка.
  def client_search
    @conversation = find_record ClientConversation
    @clients = policy_scope(Client).search(client_q: params[:q]).limit(10)
  end

  def bind_client
    @conversation = find_record ClientConversation
    @conversation.bind_client!(policy_scope(Client).find_by(id: params[:client_id]))
    load_card
    render :update_card
  end

  private

  def reply_params
    params.fetch(:client_message, {}).permit(:body, :photo)
  end

  # Всё, что нужно партиалу карточки. Зовётся из show и из всех действий,
  # которые её перерисовывают.
  def load_card
    @messages = @conversation.messages.chronological.includes(:user)
    @cities = City.with_real_departments
  end

  def filtered_scope
    scope =
      case @filter
      when 'mine'   then ClientConversation.opened.assigned_to(current_user)
      when 'open'   then ClientConversation.opened
      when 'closed' then ClientConversation.closed
      else ClientConversation.awaiting_reply
      end

    scope = scope.where(city_id: params[:city_id]) if params[:city_id].present?
    scope = scope.in_channel(params[:channel]) if params[:channel].present?
    scope
  end

  # «Без ответа» — рабочая очередь, наверх поднимается тот, кто ждёт дольше
  # всех. Остальные вкладки справочные, там естественнее свежие сверху.
  def ordered(scope)
    @filter == 'awaiting' ? scope.order(last_inbound_at: :asc) : scope.recent
  end

  def filter_counts
    {
      'awaiting' => ClientConversation.awaiting_reply.count,
      'mine' => ClientConversation.opened.assigned_to(current_user).count,
      'open' => ClientConversation.opened.count,
      'closed' => ClientConversation.closed.count
    }
  end
end
