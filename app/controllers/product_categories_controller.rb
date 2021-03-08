class ProductCategoriesController < ApplicationController
  def index
    authorize ProductCategory
    @product_categories = ProductCategory.all

    respond_to do |format|
      format.html
      format.json { render json: @product_categories }
    end
  end

  def new
    @product_category = authorize ProductCategory.new

    respond_to do |format|
      format.html { render 'form' }
      format.json { render json: @product_category }
    end
  end

  def edit
    @product_category = find_record ProductCategory

    respond_to do |format|
      format.html { render 'form' }
    end
  end

  def create
    @product_category = authorize ProductCategory.new(product_category_params)

    respond_to do |format|
      if @product_category.save
        format.html { redirect_to product_categories_path, notice: t('product_categories.created') }
        format.json { render json: @product_category, status: :created, location: @product_category }
      else
        format.html { render 'form' }
        format.json { render json: @product_category.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @product_category = find_record ProductCategory

    respond_to do |format|
      if @product_category.update_attributes(product_category_params)
        format.html { redirect_to product_categories_path, notice: t('product_categories.updated') }
        format.json { head :no_content }
      else
        format.html { render 'form' }
        format.json { render json: @product_category.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @product_category = find_record ProductCategory
    @product_category.destroy

    respond_to do |format|
      format.html { redirect_to product_categories_url }
      format.json { head :no_content }
    end
  end

  def product_category_params
    params.require(:product_category)
          .permit(:name, :kind, :feature_accounting, :request_price, :warranty_term, :feature_type_ids)

  end
end
