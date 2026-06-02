class TestingPolicy < ApplicationPolicy
  # Headless-политика: record — это символ :testing, отдельной записи нет.
  # Витрину входящих видит любой аутентифицированный сотрудник; что именно
  # он увидит — ограничивается фильтром по его локации в контроллере.
  def index?
    user.present?
  end
end
