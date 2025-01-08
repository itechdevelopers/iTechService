# frozen_string_literal: true

class RepairGroup < ApplicationRecord
  has_ancestry orphan_strategy: :restrict, cache_depth: true
  has_many :repair_services
  has_many :product_groups
  validates_presence_of :name
end
