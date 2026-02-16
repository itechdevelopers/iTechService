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
end
