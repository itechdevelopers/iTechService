# frozen_string_literal: true

class ReviewSourceAlertPolicy < ApplicationPolicy
  # Аварии заводит только парсер-агент (role: 'api'), как и отзывы.
  def create?
    user.api?
  end

  # Состояние источников смотрят те же люди, что разбирают негативные отзывы:
  # для остальных это чужая техническая информация.
  def index?
    superadmin? || able_to?(:manage_negative_reviews)
  end
end
