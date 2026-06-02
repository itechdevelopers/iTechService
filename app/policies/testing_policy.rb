class TestingPolicy < ApplicationPolicy
  # Headless-политика: record — это символ :testing, отдельной записи нет.
  # Витрину входящих видит любой аутентифицированный сотрудник; что именно
  # он увидит — ограничивается фильтром по его локации в контроллере.
  def index?
    user.present?
  end

  # Гейтит существование экшена для аутентифицированного сотрудника.
  # Ограничение «только своя локация» обеспечивает accessible_sessions
  # в контроллере (headless-политика не видит конкретную запись).
  def start?
    index?
  end

  def finish?
    index?
  end
end
