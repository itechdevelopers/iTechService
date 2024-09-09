class ReportCardsController < ApplicationController
  before_action :set_card

  def update_annotation
    @report_card.update(annotation_params)
    respond_to(&:js)
  end

  private

  def set_card
    @report_card = find_record ReportCard
  end

  def annotation_params
    params.require(:report_card).permit(:annotation)
  end
end
