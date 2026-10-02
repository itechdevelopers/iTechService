# Справочник ведёт только суперадмин: отметка уходит на сайт через Repair API, и её id
# разработчик сайта держит у себя. Просмотр закрыт тоже — в отличие от CommonPolicy,
# где read? открыт всем.
class RepairServiceMarkPolicy < ApplicationPolicy
  def read?
    superadmin?
  end

  def manage?
    superadmin?
  end
end
