# frozen_string_literal: true

class LegalEntityPolicy < ApplicationPolicy
  def manage?
    any_admin?
  end

  def link?
    manage?
  end

  def unlink?
    manage?
  end

  def sample_act?
    manage?
  end
end
