class AddReportCardForSpMovements < ActiveRecord::Migration[5.1]
  def up
    rep_board = ReportsBoard.find_by(name: "Default")
    rep_col = rep_board.report_columns.find_by(name: "Общая")
    pos = rep_col.last_card_position + 1
    ReportCard.create(content: "spare_part_movements", report_column_id: rep_col.id, position: pos)
  end

  def down
    ReportCard.where(content: "spare_part_movements").first.destroy
  end
end
