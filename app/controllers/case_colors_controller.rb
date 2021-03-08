# frozen_string_literal: true

class CaseColorsController < ApplicationController
  def index
    authorize CaseColor
    @case_colors = policy_scope(CaseColor).ordered_by_name
    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @case_colors }
    end
  end

  def new
    @case_color = authorize CaseColor.new
    respond_to do |format|
      format.html { render 'form' }
      format.json { render json: @case_color }
    end
  end

  def edit
    @case_color = find_record CaseColor
    respond_to do |format|
      format.html { render 'form' }
      format.json { render json: @case_color }
    end
  end

  def create
    @case_color = authorize CaseColor.new(case_color_params)
    respond_to do |format|
      if @case_color.save
        format.html { redirect_to case_colors_path, notice: t('case_colors.created') }
        format.json { render json: @case_color, status: :created, location: @case_color }
      else
        format.html { render 'form' }
        format.json { render json: @case_color.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @case_color = find_record CaseColor
    respond_to do |format|
      if @case_color.update_attributes(params[:case_color])
        format.html { redirect_to case_colors_path, notice: t('case_colors.updated') }
      else
        format.html { render 'form' }
        format.json { render json: @case_color.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @case_color = find_record CaseColor
    @case_color.destroy
    respond_to do |format|
      format.html { redirect_to case_colors_url }
      format.json { head :no_content }
    end
  end

  def case_color_params
    params.require(:case_color).permit(:color, :name)
  end
end
