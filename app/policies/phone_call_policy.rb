class PhoneCallPolicy < ApplicationPolicy
  def index?
    !user.is_fired? && (superadmin? || able_to?(:work_with_telephony) || able_to?(:listen_all_transcriptions))
  end
  def audio?
    !user.is_fired? && (any_admin? || able_to?(:listen_all_transcriptions) || (able_to?(:work_with_telephony) && record.answered_user_id == user.id))
  end
end
