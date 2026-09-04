# frozen_string_literal: true

class UniformKindsController < ApplicationController
  def index
    authorize UniformKind
    @uniform_kinds = UniformKind.ordered.includes(:uniform_stocks)
  end

  def new
    @uniform_kind = authorize UniformKind.new
  end

  def create
    @uniform_kind = authorize UniformKind.new(uniform_kind_params)

    if @uniform_kind.save
      redirect_to uniform_kinds_path, notice: t('.created')
    else
      render :new
    end
  end

  def edit
    @uniform_kind = find_record UniformKind
  end

  def update
    @uniform_kind = find_record UniformKind

    if @uniform_kind.update(uniform_kind_params)
      redirect_to uniform_kinds_path, notice: t('.updated')
    else
      render :edit
    end
  end

  def destroy
    @uniform_kind = find_record UniformKind
    @uniform_kind.destroy
    redirect_to uniform_kinds_path, notice: t('.destroyed')
  end

  private

  def uniform_kind_params
    params.require(:uniform_kind).permit(
      :name, :description, :cost, :image, :image_cache, :remove_image, sizes: []
    )
  end
end
