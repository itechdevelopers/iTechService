class PhoneSubstitution::Contract::Base < BaseContract
  model :phone_substitution
  property :substitute_phone, writeable: false
  properties :condition_match, :icloud_connected, :manager_informed, virtual: true
  property :condition_match
  validates :condition_match, presence: true
  # validates :icloud_connected, acceptance: true
  # validates :manager_informed, acceptance: true, if: :condition_not_match?

  def condition_not_match?
    condition_match == '0'
  end
end
