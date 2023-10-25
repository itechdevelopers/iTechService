# frozen_string_literal: true

class OrderNotesController < ApplicationController
  before_action :find_order

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
    order_note = @order.notes.build(order_note_params)
    order_note.author = current_user

    respond_to do |format|
      if order_note.save
        format.js { render 'create', locals: { order_note: order_note } }
      else
        format.js { render_error order_note.errors.full_messages.join('. ') }
      end
    end
  end

  private

  def find_order
    @order = Order.find(params[:order_id])
  end

  def order_note_params
    params.require(:order_note)
          .permit(:author_id, :content, :order_id)
  end
end
