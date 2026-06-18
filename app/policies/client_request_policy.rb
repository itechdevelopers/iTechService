class ClientRequestPolicy < ApplicationPolicy
  # Просмотр списка/карточки и СОЗДАНИЕ запросов доступны любому залогиненному
  # сотруднику — галочка work_with_receipt_search_requests больше не требуется.
  # Это сознательное открытие доступа: запрос может завести кто угодно, а список
  # видят все (см. решение в ветке 159-client-requests-receipt-search).
  # ОБРАБОТКА запроса (update_status / edit) и удаление остаются за
  # superadmin ∪ галочкой — см. permitted? / destroy?.
  def index?
    true
  end

  def show?
    true
  end

  # Иконка часов (history-экшен) доступна тем же, кто видит запрос.
  def history?
    show?
  end

  def create?
    true
  end

  def new?
    create?
  end

  def update?
    permitted?
  end

  def edit?
    update?
  end

  # Кастомный member-экшен — Pundit требует одноимённый предикат.
  def update_status?
    update?
  end

  def destroy?
    superadmin?
  end

  private

  # Право ОБРАБОТКИ запроса (смена статуса / редактирование): суперадмин ∪
  # сотрудник с галочкой ability. Тот же набор, что и адресаты уведомлений
  # (план §5). Создание и просмотр сюда больше не завязаны — см. index?/create?.
  def permitted?
    superadmin? || able_to?(:work_with_receipt_search_requests)
  end
end
