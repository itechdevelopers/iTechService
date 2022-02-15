class PhoneSubstitution < ApplicationRecord
  scope :in_department, ->(department) { where substitute_phone_id: SubstitutePhone.in_department(department) }
  scope :ordered, -> { order issued_at: :desc }
  scope :pending, -> { where withdrawn_at: nil }

  belongs_to :service_job
  belongs_to :substitute_phone
  belongs_to :issuer, class_name: 'User'
  belongs_to :receiver, class_name: 'User', optional: true

  delegate :client, :ticket_number, :department, :department_id, to: :service_job

  def pending?
    withdrawn_at.nil?
  end

  def phone_presentation
    substitute_phone.presentation
  end
end
