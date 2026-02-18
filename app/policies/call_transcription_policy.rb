class CallTranscriptionPolicy < ApplicationPolicy
  def create?
    user.api?
  end

  def index?
    superadmin?
  end

  def show?
    user.present?
  end

  def audio?
    any_admin?
  end
end
