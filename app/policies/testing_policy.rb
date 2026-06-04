class TestingPolicy < ApplicationPolicy
  # Headless-политика: record — это символ :testing, отдельной записи нет.
  # Витрину входящих + работу с тестами видят только сотрудники локаций,
  # участвующих в расписании (for_schedule = location.schedule?), плюс админы.
  # Что именно увидит сотрудник — дополнительно сужается фильтром по его
  # локации в контроллере (accessible_sessions).
  def index?
    user.present? && (user.any_admin? || user.location&.schedule?)
  end

  # Старт/завершение теста — та же аудитория, что и витрина (тестировщики).
  def start?
    index?
  end

  def finish?
    index?
  end

  # «Вернулось с тестирования» и снятие с паузы — сторона технаря-отправителя,
  # а не тестировщика. Гейтится фильтром sender_id в контроллере и не зависит
  # от for_schedule-локации, поэтому доступно любому аутентифицированному.
  def returned?
    user.present?
  end

  def resume?
    user.present?
  end
end
