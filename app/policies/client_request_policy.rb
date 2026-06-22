class ClientRequestPolicy < ApplicationPolicy
  # Запросы клиентов в основном открыты: любой залогиненный сотрудник может
  # просматривать список/карточку, создавать, обрабатывать (смена статуса через
  # update_status?) и удалять запросы. Галочка work_with_receipt_search_requests
  # и роль superadmin больше нигде не требуются — сознательное решение в ветке
  # 159-client-requests-receipt-search (адресаты уведомлений при этом остаются
  # прежними: superadmin ∪ галочка — см. ClientRequest.notification_recipients).
  #
  # ИСКЛЮЧЕНИЕ (ветка 161-client-requests-edit): полное редактирование
  # (устройство / дата покупки / комментарий через edit?/update?) — ТОЛЬКО
  # superadmin. Это правка «фактуры» запроса (исправление ошибочного серийника,
  # ручная простановка даты покупки), поэтому права у́же, чем у смены статуса.
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
    superadmin?
  end

  def edit?
    superadmin?
  end

  # Кастомный member-экшен — Pundit требует одноимённый предикат.
  def update_status?
    true
  end

  def destroy?
    true
  end
end
