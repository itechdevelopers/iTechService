# frozen_string_literal: true

# Справочник видов формы и складская сводка. Ведёт учёт не обязательно суперадмин,
# поэтому доступ открывает ещё и галочка manage_uniform.
class UniformKindPolicy < ApplicationPolicy
  def manage?
    superadmin? || able_to?(:manage_uniform)
  end

  # Нестандартный экшен: Pundit ищет метод по имени действия, и без него
  # страница отчёта падала бы на авторизации.
  def report?
    index?
  end
end
