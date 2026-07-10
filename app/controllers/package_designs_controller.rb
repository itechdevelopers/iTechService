# frozen_string_literal: true

class PackageDesignsController < ApplicationController
  # Read-only «табличка» пакетов для админа (просмотр остатков).
  def index
    authorize PackageDesign
    @package_designs =
      PackageDesign.ordered.includes(:package_stocks)
  end

  def new
    @package_design = authorize PackageDesign.new
    build_missing_sizes(@package_design)
  end

  def create
    @package_design = authorize PackageDesign.new(package_design_params)

    if @package_design.save
      redirect_to package_designs_path, notice: t('.created')
    else
      build_missing_sizes(@package_design)
      render :new
    end
  end

  def edit
    @package_design = find_record PackageDesign
    build_missing_sizes(@package_design)
  end

  def update
    @package_design = find_record PackageDesign

    if @package_design.update(package_design_params)
      redirect_to package_designs_path, notice: t('.updated')
    else
      build_missing_sizes(@package_design)
      render :edit
    end
  end

  def destroy
    @package_design = find_record PackageDesign
    @package_design.destroy
    redirect_to package_designs_path, notice: t('.destroyed')
  end

  private

  # В форме всегда показываем ровно 3 строки размеров (по одной на enum-размер):
  # существующие + достроенные пустые для недостающих. Так админ добавляет/убирает
  # размеры без динамического JS, а размер строки фиксирован (дубли невозможны).
  def build_missing_sizes(design)
    existing = design.package_stocks.map(&:size)
    (PackageStock.sizes.keys - existing).each do |size|
      design.package_stocks.build(size: size)
    end
  end

  def package_design_params
    params.require(:package_design).permit(
      :name, :image, :image_cache, :remove_image,
      package_stocks_attributes: %i[id size boxes_count per_box_count low_stock_threshold _destroy]
    )
  end
end
