#frozen_string_literal: true

module Orders
  class OneCDataService
    attr_reader :order

    def initialize(order)
      @order = order
    end

    def prepare_data
      order_data = {
        phone: order.customer&.full_phone_number,
        department_id: order.department&.code_one_c.to_s,
        department_name: order.department&.name,
        article: order.article,
        price: order.approximate_price&.to_s,
        preorder: !order.source_store.present?,
        source_store_name: order.source_store&.name,
        is_available_in_stock: order.source_store.present?,
        quantity: order.quantity,
        comment: build_comment_with_user_info,
        app_order_url: "https://ise.itech.pw/orders/#{order.id}",
        order_number: order.number,
        order_date: Time.current.strftime('%Y-%m-%d'),
        order_status: format_status_for_one_c
      }
      
      # Only add department_from_id if source_department exists and has code_one_c
      if order.source_department&.code_one_c.present?
        order_data[:department_from_id] = order.source_department.code_one_c.to_s
      end
      
      # Only add desired_date if it's present
      if order.desired_date.present?
        order_data[:desired_date] = order.desired_date.strftime('%Y-%m-%d')
      end
      
      { order: order_data }
    end

    private

    def build_comment_with_user_info
      user_info = if order.user.present?
        "Создал заказ сотрудник: #{order.user.short_name}, id сотрудника: #{order.user.id}"
      else
        "Создал заказ сотрудник: Не указан"
      end
      
      if order.comment.present?
        "#{order.comment}\n\n#{user_info}"
      else
        user_info
      end
    end

    def format_status_for_one_c
      # Special case for 'notified' status to use "Уведомлен" instead of "Уведомлён"
      status_text = if order.status == 'notified'
                      'Уведомлен'
                    else
                      I18n.t("orders.statuses.#{order.status}")
                    end
      
      # Convert to camelCase: split by spaces, capitalize each word, join without spaces
      status_text.split(' ').map(&:capitalize).join
    end
  end
end
