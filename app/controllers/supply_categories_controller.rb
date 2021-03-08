class SupplyCategoriesController < ApplicationController
  def index
    authorize SupplyCategory
    @supply_categories = SupplyCategory.arrange(order: :name)
    respond_to do |format|
      format.html
      format.json { render json: @supply_categories }
    end
  end

  def show
    @supply_category = find_record SupplyCategory
    @supply_categories = @supply_category.has_children? ? @supply_category.children : SupplyCategory.roots
    respond_to do |format|
      format.js
    end
  end

  def new
    @supply_category = authorize SupplyCategory.new
    respond_to do |format|
      format.html { render 'form' }
      format.js { render 'shared/show_modal_form' }
    end
  end

  def edit
    @supply_category = find_record SupplyCategory
    respond_to do |format|
      format.js
    end
  end

  def create
    @supply_category = authorize SupplyCategory.new(supply_category_params)
    respond_to do |format|
      if @supply_category.save
        @supply_categories = SupplyCategory.arrange(order: :name)
        format.html { redirect_to supply_categories_path, notice: t('supply_categories.created') }
        format.js
        format.json { render json: @supply_category, status: :created, location: @supply_category }
      else
        format.js { render 'shared/show_modal_form' }
        format.json { render json: @supply_category.errors.full_messages.join('. '), status: :unprocessable_entity }
      end
    end
  end

  def update
    @supply_category = find_record SupplyCategory
    respond_to do |format|
      if @supply_category.update_attributes(supply_category_params)
        format.js
        format.json { head :no_content }
      else
        format.js
        format.json { render json: @supply_category.errors.full_messages.join('. '), status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @supply_category = find_record SupplyCategory
    @supply_category.destroy
    respond_to do |format|
      #format.js { redirect_to supply_categories_url }
      format.json { head :no_content }
    end
  end

  def supply_category_params
    params.require(:store)
          .permit( :name, :ancestry, :parent_id)
  end
end
