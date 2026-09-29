# frozen_string_literal: true

class LegalEntityPolicy < ApplicationPolicy
  def manage?
    any_admin?
  end
end
