# frozen_string_literal: true

# Сторона медиа: ответ на запрос технаря о согласовании с клиентом.
# Ремонт с паузы здесь НЕ снимается — это делает технарь на витрине
# «С согласования», иначе время ремонта пошло бы раньше, чем он взялся.
class ApprovalRequestsController < ApplicationController
  before_action :set_approval_request, only: %i[answer_prompt answer resume]

  # Витрина технарей «С согласования»: отвеченные запросы по ремонтам своего
  # подразделения. Видимость по отделу, а не по автору запроса — вернувшееся
  # должен видеть весь ремонтный отдел, а не только тот, кто отправлял.
  def answered
    authorize :approval_request, :answered?

    @approval_requests = ApprovalRequest.answered
                           .in_department(current_department)
                           .includes(:requester, :responder,
                                     service_job: [:client, :repair_status, :repair_pause_reason, {item: :product}])
                           .order(responded_at: :desc)
  end

  # «Продолжить ремонт»: снимаем ремонт с паузы «Ждём согласования» и берём в
  # работу. Идемпотентно — если пауза уже снята (или причина другая), ничего не
  # делаем, чтобы не плодить записи в repair_status_changes.
  def resume
    authorize :approval_request, :resume?

    service_job = @approval_request.service_job
    if service_job.repair_status&.paused? && service_job.repair_pause_reason&.waiting_approval?
      service_job.change_repair_status!(RepairStatus.by_code(RepairStatus::IN_PROGRESS), user: current_user)
      @approval_request.reload
    end

    respond_to(&:js)
  end

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
