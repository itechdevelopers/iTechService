class CallTranscriptionPolicy < ApplicationPolicy
  def create?
    user.api?
  end
end
