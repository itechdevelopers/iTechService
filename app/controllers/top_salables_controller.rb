# frozen_string_literal: true

class TopSalablesController < ApplicationController
  def index
    authorize TopSalable
    @top_salables = TopSalable.roots.ordered
    respond_to do |format|
      format.html
      format.js
    end
  end

  def show
    @top_salable = find_record TopSalable
    @top_salables = @top_salable.children
    respond_to do |format|
      format.html { render 'index' }
      format.js { render 'index' }
    end
  end

  def new
    @top_salable = authorize TopSalable.new(top_salable_params)
    respond_to do |format|
      format.html { render 'form' }
    end
  end

  def edit
    @top_salable = find_record TopSalable
    respond_to do |format|
      format.html { render 'form' }
    end
  end

  def create
    @top_salable = authorize TopSalable.new(top_salable_params)
    respond_to do |format|
      if @top_salable.save
        format.html { redirect_to (@top_salable.parent || top_salables_path), notice: t('top_salables.created') }
      else
        format.html { render 'form' }
      end
    end
  end

  def update
    @top_salable = find_record TopSalable
    respond_to do |format|
      if @top_salable.update_attributes(top_salable_params)
        format.html { redirect_to (@top_salable.parent || top_salables_path), notice: t('top_salables.updated') }
      else
        format.html { render 'form' }
      end
    end
  end

  def destroy
    @top_salable = find_record TopSalable
    @top_salable.destroy
    respond_to do |format|
      format.html { redirect_to top_salables_url }
    end
  end

  def top_salable_params
    params.require(:top_salable)
          .permit(:ancestry, :color, :name, :position, :product_id)
  end
end
