class ReportsBoardsController < ApplicationController
  layout "reports"

  def access_control
    authorize ReportsBoard
  end

  def show
    authorize ReportsBoard
    @reports_board = ReportsBoard.find_by(name: "Default")
  end

  def sort
    authorize ReportsBoard
    sorted_columns = JSON.parse(reports_board_params[:report_ids])["columns"]
    sorted_columns.each do |column|
      report_col = ReportColumn.find_by(id: column["id"])
      next if report_col.nil?
      column["colIds"].each do |card_id|
        ReportCard.find(card_id).update(
          report_column: report_col,
          position: column["colIds"].find_index(card_id)
        )
      end
    end

    respond_to do |format|
      format.js { head :ok }
    end
  end

  private

  def reports_board_params
    params.require(:reports_board).permit(:name, :report_ids)
  end
end
