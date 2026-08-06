# frozen_string_literal: true

class AddIBrokeItReportCard < ActiveRecord::Migration[5.1]
  CONTENT = 'i_broke_it'

  def up
    column = target_column
    return unless column

    ReportCard.find_or_create_by!(content: CONTENT) do |card|
      card.report_column = column
      card.position = column.last_card_position + 1
    end
  end

  def down
    ReportCard.where(content: CONTENT).destroy_all
  end

  private

  # Колонка с отчётами по ремонту (та же, где карточка «Отчёт по запчастям»).
  def target_column
    anchor = ReportCard.find_by(content: 'repair_parts')
    return anchor.report_column if anchor

    ReportsBoard.find_by(name: 'Default')&.report_columns&.order(:id)&.first
  end
end
