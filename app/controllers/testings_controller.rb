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

  private

  # Сессии, доступные текущему сотруднику: его локация (у админов без
  # локации — все). Используется и для списка, и для проверки прав на старт.
  def accessible_sessions
    scope = TestingSession.all
    scope = scope.where(target_location_id: current_user.location_id) if current_user.location_id.present?
    scope
  end
end
