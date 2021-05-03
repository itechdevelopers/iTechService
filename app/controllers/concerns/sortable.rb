module Sortable
  extend ActiveSupport::Concern

  included do
    helper_method :sort_column, :sort_direction

    def sort_column
      model.column_names.include?(params[:sort]) ? params[:sort] : ''
    end

    def sort_direction
      %w[asc desc].include?(params[:direction]) ? params[:direction] : 'asc'
    end
  end



  def model
    @model ||= controller_name.classify.constantize
  end
end