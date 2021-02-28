# frozen_string_literal: true

class BaseFilter
  include Interactor

  def call
    set_collection
    preload_association
    filter_collection if filter
    order_collection
  end

  def preload_association; end

  def filter_collection
    filter_by_user
    filter_by_year_month
  end

  def patch_order(key); key; end

  def order_collection
    return unless order&.any?

    orders = []
    order.each do |o|
      raise ArgumentError unless o[:direction].in?([:asc, :desc, :ASC, :DESC, 'asc', 'desc', 'ASC', 'DESC'])

      [patch_order(o[:name])].flatten.each { |patch| orders << "#{patch} #{o[:direction]}" }
    end
    context.collection = context.collection.order(orders.join(','))
  end

  def filter
    context.filter
  end

  def add_scope
    context.collection = yield(context.collection)
  end

  def order
    context.order
  end


  def filter_by_user
    add_scope { |c| c.where(user_id: filter[:user_id]) } if filter[:user_id]
  end

  def filter_by_year_month
    return unless filter[:year].present?

    year = filter[:year].to_i
    month = filter[:month].to_i if filter[:month].present?
    start_date = Date.new(year, month || 1)
    end_date = Date.new(year, month || 12).at_end_of_month

    period = start_date.beginning_of_day..end_date.end_of_day
    add_scope { |c| c.where(created_at: period) }
  end

  private

  def set_collection
    context.collection ||= /(.*)Filter/.match(self.class.name)[1].singularize.constantize
  end

  def true?(param)
    ['true', true].include?(param)
  end
end
