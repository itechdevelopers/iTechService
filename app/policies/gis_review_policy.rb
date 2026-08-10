# frozen_string_literal: true

class GisReviewPolicy < ApplicationPolicy
  # Оба метода ReviewAgentApi доступны только сервисному юзеру парсер-агента
  # (role: 'api') — ровно как CallTranscriptionPolicy#create?. Живым сотрудникам
  # эти эндпоинты не нужны: список сотрудников города они видят в интерфейсе,
  # а отзывы создаёт только агент.
  def list_employees?
    user.api?
  end

  def create?
    user.api?
  end

  # Остальные предикаты (index?, update_status?, assign?, reassign?) появятся
  # вместе с экшенами в циклах 2–3. Дефолты ApplicationPolicy отдают их
  # суперадмину, так что «дыры» до тех пор нет.
end
