# frozen_string_literal: true

# Headless-политика: у согласований две стороны с разными правами.
#
#   медиа   — видит блок запросов и отвечает на них (index?/answer?);
#   технарь — видит витрину «С согласования» и снимает ремонт с паузы
#             (answered?/resume?).
#
# Конкретную запись политика не проверяет — контроллер дополнительно сужает
# выборку подразделением сотрудника (in_department), это и есть защита от IDOR.
class ApprovalRequestPolicy < ApplicationPolicy
  def index?
    user.present? && (user.any_admin? || user.location&.is_media?)
  end

  def answer?
    index?
  end

  def answered?
    user.present? && (user.any_admin? || user.location&.is_any_repair?)
  end

  def resume?
    answered?
  end
end
