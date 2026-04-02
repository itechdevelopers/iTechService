class ClientCharacteristic < ApplicationRecord
  belongs_to :client_category, optional: true
  belongs_to :set_by_user, class_name: 'User', optional: true
  has_one :client, dependent: :nullify
  has_many :history_records, as: :object, dependent: :nullify
  # attr_accessible :comment, :client_category_id
  delegate :name, :color, to: :client_category, allow_nil: true

  before_save :set_audit_fields, if: :audit_fields_changed?

  private

  def audit_fields_changed?
    client_category_id_changed? || comment_changed?
  end

  def set_audit_fields
    self.set_by_user = User.current if User.current.present?
    self.set_at = Time.current
  end
end
