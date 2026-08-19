# frozen_string_literal: true

# Сторона медиа: ответ на запрос технаря о согласовании с клиентом.
# Ремонт с паузы здесь НЕ снимается — это делает технарь на витрине
# «С согласования», иначе время ремонта пошло бы раньше, чем он взялся.
class ApprovalRequestsController < ApplicationController
  before_action :set_approval_request, only: %i[answer_prompt answer]

  def answer_prompt
    authorize :approval_request, :answer?
    render 'shared/show_modal_form'
  end

  def answer
    authorize :approval_request, :answer?
    # answer! вернёт false, если запрос уже отвечен (двойной клик, «назад»):
    # блок всё равно перерисовываем — карточка просто уйдёт из списка.
    @approval_request.answer!(outcome: params[:outcome],
                              comment: params[:response_comment],
                              user: current_user)

    respond_to(&:js)
  end

  private

  # scope-then-find: запросы чужого подразделения недоступны даже по прямой
  # ссылке (404). Headless-политика конкретную запись не проверяет.
  def set_approval_request
    @approval_request = ApprovalRequest.in_department(current_department).find(params[:id])
  end
end
