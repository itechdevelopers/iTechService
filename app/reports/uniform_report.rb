class UniformReport < BaseReport
  params %i[start_date end_date department_id xlsx_format]
  def call
    users = User.active.where.not(uniform_sex: nil).where.not(uniform_sex: '')
    users = users.in_department(department) if department
    users = users.order(:uniform_sex, :uniform_size).group(:uniform_sex, :uniform_size)
    users = users.select(:uniform_sex, :uniform_size, "array_agg(surname||' '||name||' '||patronymic) staff", 'count(*) as qty')
    result[:uniforms] = users.as_json

    result
  end

  def to_xlsx(workbook)
    workbook.add_worksheet(name: 'Uniforms Report') do |sheet|
      header_style = sheet.styles.add_style(
        bg_color: 'E6E6E6',
        b: true,
        alignment: { horizontal: :center, vertical: :center },
        border: { style: :thin, color: '000000' }
      )

      cell_style = sheet.styles.add_style(
        border: { style: :thin, color: '000000' },
        alignment: { horizontal: :left, vertical: :center }
      )

      sheet.add_row [
                      User.human_attribute_name(:uniform_sex),
                      User.human_attribute_name(:uniform_size),
                      I18n.t('reports.qty'),
                      I18n.t('reports.uniform.staff')
                    ], style: header_style

      result[:uniforms].each do |uniform|
        sheet.add_row [
                        uniform['uniform_sex'],
                        uniform['uniform_size'],
                        uniform['qty'],
                        uniform['staff'].join(', ')
                      ], style: cell_style
      end

      sheet.column_widths 15, 20, 15, 100
    end
  end
end
