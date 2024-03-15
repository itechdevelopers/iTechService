module Kanban
  class BoardPolicy < CommonPolicy
    def manage?
      superadmin?
    end

    def show?
      superadmin? || record.allowed_user_ids.include?(user.id)
    end

    def sorted?
      read?
    end
  end
end
