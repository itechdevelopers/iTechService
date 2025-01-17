module Kanban
  class CardPolicy < CommonPolicy
    def modify?
      true
    end

    def unarchive?
      true
    end
  end
end
