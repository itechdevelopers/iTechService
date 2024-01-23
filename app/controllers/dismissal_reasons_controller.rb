class DismissalReasonsController < ApplicationController
  before_action :set_dismissal_reason, only: %i[edit update destroy]

  def index
    authorize DismissalReason
    @dismissal_reasons = DismissalReason.all

    respond_to do |format|
      format.html
    end
  end

  def new
    @dismissal_reason = authorize DismissalReason.new
    respond_to do |format|
      format.html { render 'form' }
    end
  end

  def edit
    respond_to do |format|
      format.html { render 'form' }
    end
  end

  def create
    @dismissal_reason = authorize DismissalReason.new(dismissal_reason_params)
    respond_to do |format|
      if @dismissal_reason.save
        format.html { redirect_to dismissal_reasons_path, notice: t('dismissal_reasons.created') }
      else
        format.html { render 'form' }
      end
    end
  end

  def update
    respond_to do |format|
      if @dismissal_reason.update(dismissal_reason_params)
        format.html { redirect_to dismissal_reasons_path, notice: t('dismissal_reasons.updated') }
      else
        format.html { render 'form' }
      end
    end
  end

  def destroy
    @dismissal_reason.destroy
    respond_to do |format|
      format.html { redirect_to dismissal_reasons_path }
    end
  end

  private

  def set_dismissal_reason
    @dismissal_reason = find_record DismissalReason
  end

  def dismissal_reason_params
    params.require(:dismissal_reason).permit(:name)
  end
end