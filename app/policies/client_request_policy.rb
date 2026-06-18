class ClientRequestPolicy < ApplicationPolicy
  # Запросы клиентов полностью открыты: любой залогиненный сотрудник может
  # просматривать список/карточку, создавать, обрабатывать (смена статуса /
  # редактирование) и удалять запросы. Галочка work_with_receipt_search_requests
  # и роль superadmin больше нигде не требуются — сознательное решение в ветке
  # 159-client-requests-receipt-search (адресаты уведомлений при этом остаются
  # прежними: superadmin ∪ галочка — см. ClientRequest.notification_recipients).
  def index?
    true
  end

  def show?
    true
  end

  # Иконка часов (history-экшен).
  def history?
    true
  end

  def create?
    true
  end

  def new?
    true
  end

  def update?
    true
  end

  def edit?
    true
  end

  # Кастомный member-экшен — Pundit требует одноимённый предикат.
  def update_status?
    true
  end

  def destroy?
    true
  end
end
