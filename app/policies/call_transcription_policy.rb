class CallTranscriptionPolicy < ApplicationPolicy
  def create?
    user.api?
  end

  def index?
    superadmin? || able_to?(:listen_all_transcriptions)
  end

  def show?
    user.present?
  end

  def audio?
    any_admin? || able_to?(:listen_all_transcriptions)
  end
end
