module Kanban
  class CardPolicy < CommonPolicy
    def modify?
      true
    end
  end
end
