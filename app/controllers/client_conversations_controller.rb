# frozen_string_literal: true

class ClientConversationsController < ApplicationController
  # Порядок определяет и порядок чипов на странице. По умолчанию открывается
  # «Без ответа» — это рабочая очередь, всё остальное справочное.
  FILTERS = %w[awaiting mine open closed].freeze
  PER_PAGE = 200

  def index
    authorize ClientConversation

    @filter = FILTERS.include?(params[:filter]) ? params[:filter] : FILTERS.first
    @departments = Department.real
    @counts = filter_counts
    @conversations = ordered(filtered_scope).includes(:client, :department, :assigned_user)
                                            .limit(PER_PAGE).to_a
    @last_messages = last_messages_for(@conversations)
  end

  def show
    @conversation = find_record ClientConversation
    load_messages
  end

  # Ответ клиенту. Сообщение сначала ложится в ленту со статусом pending и
  # только потом уходит джобом — сотрудник видит свою реплику сразу, а её
  # судьбу («не доставлено») узнаёт из той же строки.
  def reply
    @conversation = find_record ClientConversation
    body = reply_params[:body].to_s.strip

    photo = reply_params[:photo]

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

    # jquery_ujs отменяет AJAX, если в форме выбран файл, и отправляет её
    # обычным способом — поэтому у экшена обязан быть HTML-ответ, иначе
    # отправка фото падала бы с ActionView::MissingTemplate.
    respond_to do |format|
      format.js
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
    load_messages
    render :update_card
  end

  def close
    @conversation = find_record ClientConversation
    @conversation.close!(current_user) if @conversation.open?
    load_messages
    render :update_card
  end

  private

  def reply_params
    params.fetch(:client_message, {}).permit(:body, :photo)
  end

  def load_messages
    @messages = @conversation.messages.chronological.includes(:user)
  end

  def filtered_scope
    scope =
      case @filter
      when 'mine'   then ClientConversation.opened.assigned_to(current_user)
      when 'open'   then ClientConversation.opened
      when 'closed' then ClientConversation.closed
      else ClientConversation.awaiting_reply
      end

    scope = scope.where(department_id: params[:department_id]) if params[:department_id].present?
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

  # Последнее сообщение каждого диалога — двумя запросами вместо N+1 на
  # conversation.messages.last в каждой строке таблицы.
  def last_messages_for(conversations)
    return {} if conversations.empty?

    # Служебные записи в колонку не годятся: сотруднику нужно видеть, что
    # сказал клиент или что ответили ему, а не «диалог взят в работу».
    ids = ClientMessage.where(client_conversation_id: conversations.map(&:id))
                       .where.not(kind: 'system')
                       .group(:client_conversation_id).maximum(:id)
    ClientMessage.where(id: ids.values).index_by(&:client_conversation_id)
  end
end
