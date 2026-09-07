# frozen_string_literal: true

# Движения формы заводят те же, кто ведёт справочник видов.
class UniformOperationPolicy < ApplicationPolicy
  def manage?
    superadmin? || able_to?(:manage_uniform)
  end
end
