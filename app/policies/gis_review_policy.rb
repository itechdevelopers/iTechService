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

  # Негативные отзывы: суперадмин или обладатель права manage_negative_reviews.
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

  # Страницу привязки видят все сотрудники: каждый смотрит отзывы своего города
  # и может заявить, что отзыв его. Прямая привязка остаётся под правом — assign?.
  def assignment?
    user.present?
  end

  # Подать заявку «этот отзыв мой» может любой сотрудник.
  def claim?
    user.present?
  end

  # Очередь модерации, история и решения по заявкам — та же аудитория, что
  # у негативных отзывов.
  def claims?
    index?
  end

  def claims_history?
    index?
  end

  def approve_claim?
    index?
  end

  def reject_claim?
    index?
  end

  def statistics?
    index?
  end

  def assign?
    index?
  end

  # Перекинуть УЖЕ привязанный отзыв другому сотруднику может только суперадмин.
  # Контроллер вызывает этот предикат дополнительно, когда сотрудник уже есть.
  def reassign?
    superadmin?
  end
end
