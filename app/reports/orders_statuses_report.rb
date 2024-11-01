class OrdersStatusesReport < BaseReport
  params %i[start_date end_date department_id xlsx_format]
  def call
    Order.includes(:user).where(created_at: period).in_department(department).find_each do |order|
      user_name = order.user.full_name

      if result.has_key?(user_name)
        result[user_name][:total] += 1

        if result[user_name].has_key?(order.status)
          result[user_name][order.status] += 1
        else
          result[user_name].store(order.status, 1)
        end
      else
        result.store(user_name, {:total => 1, order.status => 1})
      end
    end
  end

  def to_xlsx(workbook)
    workbook.add_worksheet(name: 'Orders Status Report') do |sheet|
      header_style = sheet.styles.add_style(
        bg_color: 'E6E6E6',
        b: true,
        alignment: { horizontal: :center, vertical: :center },
        border: { style: :thin, color: '000000' }
      )

      cell_style = sheet.styles.add_style(
        border: { style: :thin, color: '000000' },
        alignment: { horizontal: :center, vertical: :center }
      )

      name_cell_style = sheet.styles.add_style(
        border: { style: :thin, color: '000000' },
        alignment: { horizontal: :left, vertical: :center }
      )

      headers = [
        'ФИО сотрудника',
        'Всего'
      ]
      headers += Order::STATUSES.map { |status| I18n.t("orders.statuses.short.#{status}") }
      sheet.add_row headers, style: header_style

      result.each do |user_name, orders|
        row_data = [
          user_name,
          orders[:total]
        ]
        row_data += Order::STATUSES.map { |status| orders[status] }

        styles = [name_cell_style]
        styles += [cell_style] * (row_data.length - 1)
        sheet.add_row row_data, style: styles
      end

      widths = [40]
      widths += [15] * (Order::STATUSES.length + 1)
      sheet.column_widths(*widths)
    end
  end
end
