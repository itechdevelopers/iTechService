class TelephonyPolicy < ApplicationPolicy
  def use?
    Telephony::Configuration.enabled? && !user.is_fired? && user.able_to?('work_with_telephony') && User::TELEPHONY_EXTENSIONS.include?(user.telephony_extension)
  end
  alias_method :show?, :use?
  alias_method :ticket?, :use?
  alias_method :caller?, :use?
end
