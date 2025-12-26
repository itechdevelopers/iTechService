class CallTranscriptionPolicy < ApplicationPolicy
  def create?
    user.api?
  end

  def index?
    superadmin?
  end

  def show?
    superadmin?
  end
end
