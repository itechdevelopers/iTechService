# frozen_string_literal: true

# Витрина входящих на тестирование устройств для сотрудников целевого отдела.
# Видимость и право старта — по локации сотрудника (current_user.location).
class TestingsController < ApplicationController
  def index
    authorize :testing, :index?

    @testing_sessions = accessible_sessions.active
                          .includes(:sender, :tester, :target_location, service_job: :client)
                          .chronological
  end

  # «ВЕРНУЛОСЬ С ТЕСТИРОВАНИЯ» у технаря: завершённые сессии, которые он сам
  # отправлял (sender), прошедшие ИЛИ возвращённые после провала (retry — нет).
  def returned
    authorize :testing, :returned?

    @testing_sessions = TestingSession.returned
                          .where(sender_id: current_user.id)
                          .includes(:tester, :target_location, service_job: :client)
                          .order(ended_at: :desc)
  end

  # Старт теста: not_started → in_progress, фиксируем tester + started_at.
  # accessible_sessions ограничивает выбор локацией сотрудника (чужую → 404).
  def start
    authorize :testing, :start?
    @testing_session = accessible_sessions.find(params[:id])
    @testing_session.start_by!(current_user)

    respond_to { |format| format.js }
  end

  # Открывает модалку завершения теста (исход — passed/failed из params).
  def finish_prompt
    authorize :testing, :finish?
    @testing_session = accessible_sessions.find(params[:id])
    @outcome = params[:outcome].to_s.presence_in(%w[passed failed]) || 'passed'

    respond_to { |format| format.js }
  end

  # Завершение теста. На retry модель возвращает новую сессию → вставляем строку.
  def finish
    authorize :testing, :finish?
    @testing_session = accessible_sessions.find(params[:id])
    @retry_session = @testing_session.finish!(
      outcome: params[:outcome],
      notes: params[:notes],
      failure_action: params[:failure_action]
    )

    respond_to { |format| format.js }
  end

  # Снятие ремонта с «тестовой» паузы после неудачного теста: paused → in_progress.
  # Отсчёт времени ремонта (return_at) возобновляется. Идемпотентно: если ремонт
  # уже снят с паузы — ничего не делаем (не плодим записи в repair_status_changes).
  def resume
    authorize :testing, :resume?
    @testing_session = TestingSession.where(sender_id: current_user.id).find(params[:id])
    service_job = @testing_session.service_job

    if service_job.repair_status&.paused?
      service_job.change_repair_status!(RepairStatus.by_code(RepairStatus::IN_PROGRESS), user: current_user)
      @testing_session.reload # сбросить устаревший после update_columns кэш repair_status
    end

    respond_to { |format| format.js }
  end

  private

  # Сессии, доступные текущему сотруднику: его локация (у админов без
  # локации — все). Используется и для списка, и для проверки прав на старт.
  def accessible_sessions
    scope = TestingSession.all
    scope = scope.where(target_location_id: current_user.location_id) if current_user.location_id.present?
    scope
  end
end
