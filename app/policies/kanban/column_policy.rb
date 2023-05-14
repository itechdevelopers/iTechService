module Kanban
  class ColumnPolicy < CommonPolicy
    def manage?
      superadmin?
    end
  end
end
