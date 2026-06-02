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

  private

  # Сессии, доступные текущему сотруднику: его локация (у админов без
  # локации — все). Используется и для списка, и для проверки прав на старт.
  def accessible_sessions
    scope = TestingSession.all
    scope = scope.where(target_location_id: current_user.location_id) if current_user.location_id.present?
    scope
  end
end
