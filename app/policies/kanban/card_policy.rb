module Kanban
  class CardPolicy < CommonPolicy
    def modify?
      true
    end

    def unarchive?
      true
    end

    def update_card_columns?
      modify?
    end
  end
end
