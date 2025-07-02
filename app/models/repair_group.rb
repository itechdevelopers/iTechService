# frozen_string_literal: true

class RepairGroup < ApplicationRecord
  has_ancestry orphan_strategy: :restrict, cache_depth: true
  has_many :repair_services, dependent: :nullify
  has_many :product_groups, dependent: :restrict_with_error
  validates_presence_of :name

  def can_be_deleted?
    errors = []
    
    if has_children?
      errors << "Cannot delete repair group with child groups"
    end
    
    if product_groups.exists?
      errors << "Cannot delete repair group with associated product groups"
    end
    
    if repair_services.joins(:repair_tasks).exists?
      errors << "Cannot delete repair group with repair services that have associated repair tasks"
    end
    
    errors
  end

  def safe_destroy
    deletion_errors = can_be_deleted?
    
    if deletion_errors.empty?
      destroy
    else
      errors.add(:base, deletion_errors.join("; "))
      false
    end
  end
end
