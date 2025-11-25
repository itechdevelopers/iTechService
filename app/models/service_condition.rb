# frozen_string_literal: true

class ServiceCondition < ApplicationRecord
  has_and_belongs_to_many :tasks

  validates :content, presence: true

  default_scope { order(:position) }
end
