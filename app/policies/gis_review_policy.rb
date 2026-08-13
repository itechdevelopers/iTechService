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

  # PATCH .../reviews/:external_review_id/employee — агент доносит сотрудника,
  # которого не смог определить при первой отправке.
  def update_employee?
    user.api?
  end

  # Страница негативных отзывов и работа с ними: суперадмин ИЛИ обладатель права
  # «Работа с негативными отзывами 2ГИС» (заказчик просил отдельное право сверх
  # суперадминов).
  def index?
    superadmin? || able_to?(:manage_negative_reviews)
  end

  def update_status?
    index?
  end

  def add_comment?
    index?
  end

  def comments?
    index?
  end

  # Страница привязки сотрудников и сама привязка — та же аудитория, что у
  # негативных отзывов.
  def assignment?
    index?
  end

  def assign?
    index?
  end

  # А вот перекинуть УЖЕ привязанный отзыв другому сотруднику — привилегия
  # суперадмина (прямое требование заказчика). Контроллер вызывает этот предикат
  # дополнительно, когда у отзыва уже есть сотрудник.
  def reassign?
    superadmin?
  end
end
