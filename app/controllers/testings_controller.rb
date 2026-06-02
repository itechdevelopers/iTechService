# frozen_string_literal: true

# Витрина входящих на тестирование устройств для сотрудников целевого отдела.
# Видимость — по локации сотрудника (current_user.location). Управление статусами
# (Play / завершение) добавляется в следующих циклах.
class TestingsController < ApplicationController
  def index
    authorize :testing, :index?

    @testing_sessions = TestingSession.active
                          .includes(:sender, :target_location, service_job: :client)
                          .chronological
    if current_user.location_id.present?
      @testing_sessions = @testing_sessions.where(target_location_id: current_user.location_id)
    end
  end
end
