# frozen_string_literal: true

class RepairGroup < ApplicationRecord
  has_ancestry orphan_strategy: :restrict, cache_depth: true
  has_many :repair_services, dependent: :nullify
  has_many :product_groups, dependent: :restrict_with_error
  validates_presence_of :name

  def can_be_deleted?
    errors = []
    
    if has_children?
      errors << "Невозможно удалить группу ремонта с дочерними группами"
    end
    
    if product_groups.exists?
      errors << "Невозможно удалить группу ремонта с привязанными группами товаров"
    end
    
    if repair_services.joins(:repair_tasks).exists?
      errors << "Невозможно удалить группу ремонта с услугами ремонта, имеющими связанные задачи"
    end
    
    errors
  end

  def safe_destroy
    deletion_errors = can_be_deleted?
    
    if deletion_errors.empty?
      begin
        destroy
      rescue ActiveRecord::DeleteRestrictionError => e
        errors.add(:base, "Невозможно удалить группу ремонта с привязанными записями")
        false
      rescue Ancestry::AncestryException => e
        errors.add(:base, "Невозможно удалить группу ремонта с дочерними группами")
        false
      rescue ActiveRecord::InvalidForeignKey => e
        errors.add(:base, "Невозможно удалить группу ремонта из-за ограничений базы данных")
        false
      rescue StandardError => e
        errors.add(:base, "Произошла ошибка при удалении группы ремонта")
        false
      end
    else
      errors.add(:base, deletion_errors.join("; "))
      false
    end
  end
end
