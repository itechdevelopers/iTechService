class ReportColumnsController < ApplicationController
  before_action :set_board
  before_action :set_column, only: %i[destroy]

  def create
    authorize ReportsBoard
    @column = @board.report_columns.build(report_column_params)
    respond_to do |format|
      if @column.save
        format.js
      else
        format.js { head :unprocessable_entity}
      end
    end
  end

  def destroy
    authorize ReportsBoard
    report_cards = @column.report_cards
    if report_cards.any?
      default_column = @board.report_columns.find_by(name: "Общая")
      pos = default_column.last_card_position
      report_cards.each do |rc|
        pos += 1
        rc.update(report_column: default_column, position: pos)
      end
    end
    @column.destroy
  end

  private

  def set_board
    @board ||= ReportsBoard.find(params[:reports_board_id])
  end

  def set_column
    @column ||= ReportColumn.find(params[:id])
  end

  def report_column_params
    params.require(:report_column).permit(:name)
  end
end