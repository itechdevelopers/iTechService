class AddReportCardForTrackedWork < ActiveRecord::Migration[5.1]
  def up
    rep_board = ReportsBoard.find_by(name: 'Default')
    rep_col = rep_board.report_columns.find_by(name: 'Общая')
    position = rep_col.last_card_position + 1
    ReportCard.create!(content: 'tracked_work', report_column_id: rep_col.id, position: position)
  end

  def down
    ReportCard.find_by(content: 'tracked_work')&.destroy
  end
end
