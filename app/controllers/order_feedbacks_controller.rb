class OrderFeedbacksController < ApplicationController
  skip_after_action :verify_authorized

  def edit
    @order_feedback = authorize OrderFeedback.find(params[:id])
    respond_to do |format|
      format.js
      format.html { redirect_to @order_feedback.order }
    end
  end

  def update
    @order_feedback = authorize OrderFeedback.find(params[:id])
    if @order_feedback.resolve!(details: params.dig(:order_feedback, :details),
                                next_reminder: params[:schedule_on], user: current_user)
      render :update
    else
      render_error @order_feedback.errors.full_messages.join('. ').presence || t('errors.messages.blank')
    end
  end

  def postpone
    @order_feedback = authorize OrderFeedback.find(params[:id]), :postpone?
    @order_feedback.postpone!(current_user)
    render :update
  end
end
