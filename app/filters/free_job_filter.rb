# frozen_string_literal: true

class FreeJobFilter < BaseFilter
  def filter_by_user
    add_scope { |c| c.where(performer_id: filter[:user_id]) } if filter[:user_id]
  end
end
