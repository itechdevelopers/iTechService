class RepairStatusSetting < ApplicationRecord
  DEFAULT_ATTENTION_TIMEOUT_SECONDS  = 300
  DEFAULT_ESCALATION_TIMEOUT_SECONDS = 3600

  validates :attention_timeout_seconds,
            presence: true,
            numericality: { only_integer: true, greater_than: 0 }
  validates :escalation_timeout_seconds,
            presence: true,
            numericality: { only_integer: true, greater_than: 0 }

  def self.instance
    first_or_create!(
      attention_timeout_seconds:  DEFAULT_ATTENTION_TIMEOUT_SECONDS,
      escalation_timeout_seconds: DEFAULT_ESCALATION_TIMEOUT_SECONDS
    )
  end
end
