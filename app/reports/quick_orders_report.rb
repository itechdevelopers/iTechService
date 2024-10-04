# frozen_string_literal: true

class QuickOrdersReport < BaseReport
  attr_reader :quick_orders_by_type, :ignored_types

  params %i[start_date end_date department_id quick_orders_by_type]

  def quick_orders_by_type=(value)
    @quick_orders_by_type = value == '1'
  end

  def ignored_types=(value)
    @ignored_types = value.reject(&:empty?).map(&:to_i)
  end
  def call
    result[:quick_by_types] = false
    return quick_by_types if quick_orders_by_type

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
        order_ids_numbers = orders.where(user: user).map { |o| { id: o.id, number: o.number_s } }
        result[:users] << { name: user.short_name, qty: total, qty_done: done, order_ids_numbers: order_ids_numbers }
      end
    end
    result
  end

  private

  def quick_by_types
    result[:quick_by_types] = true
    orders = QuickOrder.includes(:quick_tasks)
                       .where(created_at: period)
                       .in_department(department)
                       .where.not(id: QuickOrder.joins(:quick_tasks)
                                                .where(quick_tasks: { id: ignored_types })
                                                .select(:id))
    result[:total_qty] = orders.count
    if result[:total_qty].positive?
      result[:quick_tasks] = []
      orders.order('count_quick_orders_id desc')
            .group(:quick_task_id)
            .count('quick_orders.id')
            .each do |task_id, qty|
        if task_id
          task = QuickTask.find(task_id)
          task_name = task.name
        else
          task_name = 'Без задач'
        end
        percentage = (qty.to_f / result[:total_qty] * 100).round(2)
        order_ids_numbers = orders.where(quick_tasks: { id: task_id })
                                  .map { |o| { id: o.id, number: o.number_s } }
        result[:quick_tasks] << { name: task_name, qty: qty, percentage: percentage,
                                  order_ids_numbers: order_ids_numbers }
      end
    end
    result
  end
end
