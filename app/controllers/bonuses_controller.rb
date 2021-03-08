class BonusesController < ApplicationController
  def show
    @bonus = find_record Bonus
    respond_to do |format|
      format.html
      format.js
    end
  end

  def new
    @bonus = authorize Bonus.new(bonus_params)
    respond_to do |format|
      format.html { render 'form' }
    end
  end

  def edit
    @bonus = find_record Bonus
    respond_to do |format|
      format.html { render 'form' }
    end
  end

  def create
    @bonus = authorize Bonus.new(bonus_params)
    @karma_group_id = params[:bonus][:karma_group_id]
    respond_to do |format|
      if @bonus.save
        format.html { redirect_to @bonus, notice: t('bonuses.created') }
      else
        format.html { render 'form' }
      end
    end
  end

  def update
    @bonus = find_record Bonus
    respond_to do |format|
      if @bonus.update_attributes(bonus_params)
        format.html { redirect_to @bonus, notice: t('bonuses.updated') }
        format.js
      else
        format.html { render 'form' }
        format.js { render 'shared/show_modal_form' }
      end
    end
  end

  def destroy
    @bonus = find_record Bonus
    @bonus.destroy
    respond_to do |format|
      format.html { redirect_to bonus_url }
      format.js
    end
  end

  def bonus_type_params
    params.require(:bonus).permit(:comment, :bonus_type_id)
  end
end
