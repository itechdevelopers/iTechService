# frozen_string_literal: true

class QuickOrdersReport < BaseReport
  def call
    result[:users] = []
    orders = QuickOrder.includes(:user)
                       .where(created_at: period)
                       .in_department(department)
    result[:total_qty] = orders.count
    if result[:total_qty].positive?
      orders.order('count_quick_orders_id desc')
            .group(:user_id, :is_done)
            .count('quick_orders.id')
            .map { |info, qty| { user_id: info.first, is_done: info.last, qty: qty } }
            .group_by { |h| h[:user_id] }
            .each do |user_id, info|
        user = User.find(user_id)
        done = info.detect { |i| i[:is_done] }&.dig(:qty) || 0
        total = done + (info.detect { |i| !i[:is_done] }&.dig(:qty) || 0)
        result[:users] << { name: user.short_name, qty: total, qty_done: done }
      end
    end
    result
  end
end
