class SalesReport < BaseReport
  def call
    sales = Sale.sold_at(period).posted.order('date asc')
    sales = sales.in_department(department) if department.present?

    data = {
      goods: {
        name: 'Товары',
        count: 0,
        sum: 0,
        discount: 0,
        details: []
      }
    }
    total_sales_count = 0
    total_sales_sum = 0
    total_discounts_sum = 0

    sales.selling.find_each do |sale|
      sale.sale_items.each do |sale_item|
        sale_item_sum = sale_item[:price] * sale_item[:quantity]

        payment_type = sale.payment_kinds.map { |payment_kind| I18n.t("payments.kinds.#{payment_kind}") }.join(', ')

        if sale_item.is_service? && sale_item.device_task.present?
          data_key = sale_item.device_task.task_id

          if data.has_key?(data_key)
            data[data_key][:count] += 1
            data[data_key][:sum] += sale_item_sum
            data[data_key][:discount] += sale_item.discount
          else
            data.store(data_key, {
              name: sale_item.device_task.name,
              count: 1,
              sum: sale_item_sum,
              discount: sale_item.discount,
              details: []
            })
          end
        else
          data_key = :goods
          data[data_key][:count] += sale_item.quantity
          data[data_key][:sum] += sale_item_sum
          data[data_key][:discount] += sale_item.discount
        end

        data[data_key][:details] << {
          sale_id: sale.id,
          job_id: sale.service_job&.id,
          time: sale.date,
          product: sale_item.name,
          features: sale_item.features_s,
          quantity: sale_item.quantity,
          price: sale_item.price,
          sum: sale_item_sum,
          discount: sale_item.discount,
          payment_type: payment_type,
          client_id: sale.client_id,
          client: sale.client_short_name,
          user_id: sale.user_id,
          user: sale.user_short_name
        }

        total_sales_count += sale_item.quantity
        total_sales_sum += sale_item_sum
        total_discounts_sum += sale_item.discount
      end
    end

    result[:data] = data
    result[:total_sales_count] = total_sales_count
    result[:total_sales_sum] = total_sales_sum
    result[:total_discounts_sum] = total_discounts_sum
    self
  end

  private

  def sales; end
end
