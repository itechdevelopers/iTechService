# frozen_string_literal: true

class OrderNotesController < ApplicationController
  before_action :find_order, only: %i[index create]
  before_action :find_order_note, only: %i[update]

  def index
    authorize OrderNote
    @note = @order.notes.build(author: current_user)
    @modal = "order-notes-#{@order.id}"
    respond_to do |format|
      format.js { render 'shared/show_modal_form' }
    end
  end

  def create
    authorize OrderNote
    @order_note = @order.notes.build(order_note_params)
    @order_note.author = current_user

    respond_to do |format|
      if @order_note.save
        update_notifications if @notifications.any?
        format.js { render 'create', locals: { order_note: @order_note } }
      else
        format.js { render_error @order_note.errors.full_messages.join('. ') }
      end
    end
  end

  def update
    authorize @order_note
    respond_to do |format|
      if @order_note.update(order_note_params)
        updated_text = order_note_params.fetch(:content, @order_note.content)
        RecordEdit.create!(editable: @order_note, user: current_user, updated_text: updated_text)
        format.js
      else
        format.js { head :unprocessable_entity }
      end
    end
  end

  private

  def update_notifications
    @notifications.each do |notification|
      notification.update(url: order_url(@order), referenceable: @order_note, message: @order_note.content[0..50])
    end
  end

  def find_order
    @order = Order.find(params[:order_id])
  end

  def find_order_note
    @order_note = OrderNote.find(params[:id])
  end

  def order_note_params
    params.require(:order_note)
          .permit(:author_id, :content, :order_id)
  end
end
