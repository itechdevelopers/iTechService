# frozen_string_literal: true

class UserPause < ApplicationRecord
  belongs_to :user

  validates :user, :paused_at, presence: true
end 