# frozen_string_literal: true

class RepairGroup < ActiveRecord::Base
  has_ancestry orphan_strategy: :restrict, cache_depth: true
  has_many :repair_services
  validates_presence_of :name
end
