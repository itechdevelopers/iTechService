class TestingPolicy < ApplicationPolicy
  # Headless-политика: record — это символ :testing, отдельной записи нет.
  # Витрину входящих + работу с тестами видят только сотрудники локаций,
  # участвующих в тестировании (location.for_testing?), плюс админы.
  # Что именно увидит сотрудник — дополнительно сужается фильтром по его
  # локации в контроллере (accessible_sessions).
  def index?
    user.present? && (user.any_admin? || user.location&.for_testing?)
  end

  # Старт/завершение теста — та же аудитория, что и витрина (тестировщики).
  def start?
    index?
  end

  def finish?
    index?
  end

  # «Вернулось с тестирования» и снятие с паузы — сторона технаря-отправителя,
  # а не тестировщика. Доступ у сотрудников ремонтных локаций (код начинается
  # с repair, см. Location#is_any_repair?) плюс админы. Содержимое страницы
  # дополнительно сужается по sender_id в контроллере (видишь только свои).
  def returned?
    user.present? && (user.any_admin? || user.location&.is_any_repair?)
  end

  def resume?
    returned?
  end
end
