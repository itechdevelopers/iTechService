module MediaMenu
  class Item::Index < BaseOperation
    success ->(options, params:, **) {
      options['category'] = params[:category] if %w[h r n c].include?(params[:category])
    }

    step ->(options, category: nil, params:, **) {
      items = Item.movies
      items = items.in_category category unless category.nil?
      sort_param = params.key?(:sort_by) ? [params[:sort_by], params.fetch(:sort_dir, :asc)] : [:name, :asc]
      items = items.order_by(*sort_param).search(params[:search]).page(params[:page]).per(50)
      options['model'] = items
    }
  end
end
