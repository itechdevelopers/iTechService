# frozen_string_literal: true

class OneCFunctionPolicy < ApplicationPolicy
  def index?
    true # Every authenticated employee; ApplicationPolicy rejects anonymous access.
  end

  def glass?
    index?
  end

  def glass_search?
    index?
  end

  def article?
    superadmin? || able_to?(:work_with_one_c_articles)
  end
end
