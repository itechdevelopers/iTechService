class ReportsBoardsController < ApplicationController
  layout "reports"

  def access_control
    authorize ReportsBoard
    @reports_board = ReportsBoard.find(params[:id])
  end

  def assign_permissions
    authorize ReportsBoard
    @reports_board = ReportsBoard.find(params[:id])
    
    report_ids = params[:report_ids] || []
    user_ids = params[:user_ids] || []
    
    # Очищаем существующие права, если нужно
    # ReportPermission.where(report_card_id: report_ids).destroy_all if params[:clear_existing]
    
    # Создаем новые записи о правах
    success = true
    ActiveRecord::Base.transaction do
      user_ids.each do |user_id|
        report_ids.each do |report_id|
          ReportPermission.find_or_create_by(
            user_id: user_id,
            report_card_id: report_id
          )
        rescue ActiveRecord::RecordInvalid
          success = false
          raise ActiveRecord::Rollback
        end
      end
    end
    
    if success
      redirect_to reports_path, notice: 'Права доступа успешно обновлены'
    else
      redirect_to access_control_reports_board_path(@reports_board), alert: 'Произошла ошибка при обновлении прав'
    end
  end
  
  def revoke_permissions
    authorize ReportsBoard
    @reports_board = ReportsBoard.find(params[:id])
    
    report_ids = params[:report_ids] || []
    user_ids = params[:user_ids] || []
    
    if report_ids.present? && user_ids.present?
      ReportPermission.where(user_id: user_ids, report_card_id: report_ids).destroy_all
      redirect_to reports_path, notice: 'Права доступа успешно удалены'
    else
      redirect_to access_control_reports_board_path(@reports_board), alert: 'Не выбраны отчеты или пользователи'
    end
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
