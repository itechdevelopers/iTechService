# frozen_string_literal: true

class BrandsController < ApplicationController
  respond_to :html

  def index
    authorize Brand
    @brands = policy_scope(Brand)
  end

  def new
    @brand = authorize(Brand.new)
    render 'form'
  end

  def create
    @brand = authorize(Brand.new(brand_params))

    if @brand.save
      redirect_to brands_path, notice: 'Город создан'
    else
      render 'form'
    end
  end

  def edit
    @brand = find_record(Brand)
    render 'form'
  end

  def update
    @brand = find_record(Brand)

    if @brand.update(brand_params)
      redirect_to brands_path, notice: 'Бренд изменён'
    else
      render 'form'
    end
  end

  def destroy
    @brand = find_record(Brand)
    @brand.destroy
    redirect_to brands_path, notice: 'Бренд удалён'
  end

  def brand_params
    params.require(:brand).permit(:logo, :name)
  end
end
