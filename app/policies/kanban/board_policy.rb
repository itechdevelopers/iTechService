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

    def archived?
      read?
    end

    def archived_boards?
      read?
    end

    def copy?
      manage?
    end

    def archive?
      manage?
    end

    def unarchive?
      manage?
    end
  end
end
