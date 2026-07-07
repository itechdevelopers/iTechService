class BackfillOrderFeedbacks < ActiveRecord::Migration[5.1]
  ACTIVE_STATUSES = %w[new pending current on_the_way notified].freeze

  def up
    scope = Order.where(status: ACTIVE_STATUSES)
                 .where.not(desired_date: nil)
                 .where('desired_date >= ?', Date.current)

    scope.find_each do |order|
      next if order.order_feedbacks.exists?

      OrderFeedback.schedule_for(order)
    end
  end

  def down
    OrderFeedback.delete_all
  end
end
