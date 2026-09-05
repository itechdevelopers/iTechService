# frozen_string_literal: true

# Учёт рабочей формы целиком суперадминский — и просмотр, и ведение.
# ApplicationPolicy#manage? уже равен superadmin?, а index?/show?/create?/update?/
# destroy? сводятся к нему, поэтому переопределять здесь нечего.
class UniformKindPolicy < ApplicationPolicy
  # Нестандартный экшен: Pundit ищет метод по имени действия, и без него
  # страница отчёта падала бы на авторизации.
  def report?
    index?
  end
end
