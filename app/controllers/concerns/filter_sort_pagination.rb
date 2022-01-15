# frozen_string_literal: true

module FilterSortPagination
  extend ActiveSupport::Concern
  DEFAULT_LIMIT = 100

  included do
    def filter_params
      {
        filter: filter,
        order: order
      }
    end

    def filter
      if params[:filter].present?
        filter = params[:filter].is_a?(String) ? JSON.parse(params[:filter]).with_indifferent_access : permitted_filter
      else
        filter = {}
        filter[:search] = params[:search] if params[:search]
      end
      filter
    end

    def permitted_filter
      params[:filter]&.permit!
    end

    def order
      order = []
      if params[:sort].present?
        order << { name: params[:sort], direction: (params[:direction] || :asc) }
      elsif params[:order].present?
        order = if params[:order].is_a?(String)
                  JSON.parse(params[:order]).map(&:with_indifferent_access)
                else
                  params[:order].map(&:permit!)
                end
      end
      # order << { name: "#{}.created_at", direction: 'desc' } if order.detect { |o| o[:name] == 'created_at' }.blank?
      order
    end
  end

  def paginate(items)
    curr_page = action_params[:page] || action_params.dig(:pagination, :page) ||
                action_params.dig(:pagination, :current_page) || 1
    limit = action_params[:limit] || action_params.dig(:pagination, :limit) || DEFAULT_LIMIT
    items.page(curr_page).per(limit)
  end

  def pagination_info(collection)
    {
      total_count: collection.total_count,
      total_pages: collection.total_pages,
      current_page: collection.current_page,
      limit: collection.limit_value,
      prev_page: collection.prev_page || 0,
      next_page: collection.next_page || 0,
      first_page: collection.first_page?,
      last_page: collection.last_page?,
      out_of_range: collection.out_of_range?
    }
  end
end
