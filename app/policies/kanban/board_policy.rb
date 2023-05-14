module Kanban
  class BoardPolicy < CommonPolicy
    def manage?
      superadmin?
    end
  end
end
