# frozen_string_literal: true

class MessagesController < ApplicationController
  def index
    authorize Message
    @messages = policy_scope(Message).newest
    @messages = @messages.today unless params[:range] == 'all'

    respond_to do |format|
      format.html
      format.json { render json: @messages }
    end
  end

  def show
    @message = find_record Message
    respond_to do |format|
      format.js
    end
  end

  def create
    # message_params = params[:message].merge(user_id: current_user.id, department_id: current_user.department_id)
    @message = authorize Message.new(message_params)

    respond_to do |format|
      if @message.save
        ChatChannel.broadcast_message(@message)
        update_notifications if @notifications.any?
        format.html { redirect_to @message, notice: t('chat.created') }
        format.json { render json: @message, status: :created, location: @message }
        format.js
      else
        format.html { render action: 'new' }
        format.json { render json: @message.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @message = find_record Message
    @message.destroy

    respond_to do |format|
      format.html { redirect_to messages_url }
      format.json { head :no_content }
    end
  end

  private

  def update_notifications
    @notifications.each do |notification|
      notification.update(url: messages_url, referenceable: @message, message: @message.content[0..50])
    end
  end

  def message_params
    params.require(:message)
          .permit(:content, :recipient_id, :recipient_type)
          .merge(user_id: current_user.id, department_id: current_user.department_id)
  end
end