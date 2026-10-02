class RepairServiceMarksController < ApplicationController
  before_action :set_repair_service_mark, only: %i[edit update destroy]

  def index
    authorize RepairServiceMark
    @repair_service_marks = RepairServiceMark.all
    # Одним запросом на весь список: по счётчику видно, у каких отметок нет кнопки удаления.
    # unscope(:order): default_scope RepairService сортирует по name, и GROUP BY с ним падает.
    @services_count = RepairService.unscope(:order).where.not(repair_service_mark_id: nil)
                                   .group(:repair_service_mark_id).count
  end

  def new
    @repair_service_mark = authorize RepairServiceMark.new
    render 'form'
  end

  def edit
    render 'form'
  end

  def create
    @repair_service_mark = authorize RepairServiceMark.new(repair_service_mark_params)
    if @repair_service_mark.save
      redirect_to repair_service_marks_path, notice: t('repair_service_marks.created')
    else
      render 'form'
    end
  end

  def update
    if @repair_service_mark.update(repair_service_mark_params)
      redirect_to repair_service_marks_path, notice: t('repair_service_marks.updated')
    else
      render 'form'
    end
  end

  def destroy
    if @repair_service_mark.destroy
      redirect_to repair_service_marks_path, notice: t('repair_service_marks.destroyed')
    else
      redirect_to repair_service_marks_path, alert: @repair_service_mark.errors.full_messages.to_sentence
    end
  end

  private

  def set_repair_service_mark
    @repair_service_mark = find_record RepairServiceMark
  end

  def repair_service_mark_params
    params.require(:repair_service_mark).permit(:name, :title, :position)
  end
end
