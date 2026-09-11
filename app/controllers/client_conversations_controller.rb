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
    @conversations = filtered_scope.includes(:client, :department, :assigned_user)
                                   .recent.limit(PER_PAGE).to_a
    @last_messages = last_messages_for(@conversations)
  end

  def show
    @conversation = find_record ClientConversation
    @messages = @conversation.messages.chronological.includes(:user)
  end

  # Ответ клиенту. Сообщение сначала ложится в ленту со статусом pending и
  # только потом уходит джобом — сотрудник видит свою реплику сразу, а её
  # судьбу («не доставлено») узнаёт из той же строки.
  def reply
    @conversation = find_record ClientConversation
    body = reply_params[:body].to_s.strip

    if @conversation.closed?
      @error = t('.conversation_closed')
    elsif body.blank?
      @error = t('.empty_body')
    else
      @message = @conversation.messages.create!(
        direction: 'out', kind: 'text', body: body,
        user: current_user, delivery_status: 'pending'
      )
      SendClientMessageJob.perform_later(@message.id)
    end
  end

  private

  def reply_params
    params.fetch(:client_message, {}).permit(:body)
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

    ids = ClientMessage.where(client_conversation_id: conversations.map(&:id))
                       .group(:client_conversation_id).maximum(:id)
    ClientMessage.where(id: ids.values).index_by(&:client_conversation_id)
  end
end
