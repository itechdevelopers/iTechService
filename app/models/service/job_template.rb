module Service
  class JobTemplate < ApplicationRecord
    FIELD_NAMES = %w[claimed_defect device_condition type_of_work client_comment estimated_cost_of_repair trademark device_group completeness]

    self.table_name = 'service_job_templates'

    scope :ordered, -> { order :field_name }

    def self.filter(params = {})
      if params.has_key?(:field_name)
        where field_name: params[:field_name]
      else
        all
      end
    end
  end
end
