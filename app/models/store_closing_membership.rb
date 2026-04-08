# frozen_string_literal: true

class StoreClosingMembership < ApplicationRecord
  belongs_to :store_closing_group
  belongs_to :user

  validates :user_id, uniqueness: { scope: :store_closing_group_id }

  default_scope { order(:position) }
end
