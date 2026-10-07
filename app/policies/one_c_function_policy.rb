# frozen_string_literal: true

class OneCFunctionPolicy < ApplicationPolicy
  def index?
    superadmin? || able_to?(:work_with_one_c_articles)
  end
end
