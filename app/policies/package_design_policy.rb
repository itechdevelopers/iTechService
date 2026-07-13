# frozen_string_literal: true

# «Табличка» пакетов: смотреть остатки может любой сотрудник (склад общий,
# всем полезно знать наличие), а вести её — заводить/править дизайны и размеры —
# только админы/суперадмины. new?/edit? наследуются из ApplicationPolicy и зовут
# create?/update?, поэтому переопределять их отдельно не нужно.
class PackageDesignPolicy < ApplicationPolicy
  # Просмотр — всем аутентифицированным (ApplicationPolicy уже требует user).
  def index?
    true
  end

  def show?
    true
  end

  # Редактирование склада — только админы/суперадмины (any_admin? = admin|superadmin).
  def create?
    any_admin?
  end

  def update?
    any_admin?
  end

  def destroy?
    any_admin?
  end
end
