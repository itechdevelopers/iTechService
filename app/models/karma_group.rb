# frozen_string_literal: true

class KarmaGroup < ApplicationRecord
  scope :used, -> { where('bonus_id != ?', nil) }
  scope :unused, -> { where(bonus_id: nil) }

  belongs_to :bonus, inverse_of: :karma_group
  has_many :karmas, dependent: :nullify, inverse_of: :karma_group

  accepts_nested_attributes_for :bonus, reject_if: proc { |attr| attr['bonus_type_id'].blank? }

  def karma_ids=(new_value)
    if new_value.is_a?(String)
      super new_value.split(',')
    else
      super
    end
  end

  def is_used?
    bonus_id.present?
  end

  def size
    karmas.count
  end

  def user
    karmas.any? ? karmas.first.user : nil
  end
end
