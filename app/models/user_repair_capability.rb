# frozen_string_literal: true

class UserRepairCapability < ApplicationRecord
  belongs_to :user
  belongs_to :repair_service

  delegate :name, :repair_group, to: :repair_service, allow_nil: true
  delegate :short_name, to: :user, prefix: true, allow_nil: true

  validates :user_id, uniqueness: { scope: :repair_service_id, message: :already_assigned }
  validates :repair_service, :user, presence: true

  scope :ordered_by_date, -> { order(created_at: :desc) }
  scope :ordered_by_group, -> {
    includes(repair_service: :repair_group)
      .order('repair_groups.name ASC NULLS LAST, repair_services.name ASC')
  }

  def repair_group_name
    repair_group&.name
  end
end
