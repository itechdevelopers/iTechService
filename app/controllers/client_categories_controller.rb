class ClientCategoriesController < ApplicationController
  def index
    authorize ClientCategory
    @client_categories = policy_scope(ClientCategory).all
    respond_to do |format|
      format.html
    end
  end

  def new
    @client_category = authorize ClientCategory.new
    respond_to do |format|
      format.html { render 'form' }
    end
  end

  def edit
    @client_category = find_record ClientCategory
    respond_to do |format|
      format.html { render 'form' }
    end
  end

  def create
    @client_category = authorize ClientCategory.new(client_category_params)
    respond_to do |format|
      if @client_category.save
        format.html { redirect_to client_categories_path, notice: 'Client category was successfully created.' }
      else
        format.html { render 'form' }
      end
    end
  end

  def update
    @client_category = find_record ClientCategory
    respond_to do |format|
      if @client_category.update_attributes(params[:client_category])
        format.html { redirect_to client_categories_path, notice: 'Client category was successfully updated.' }
      else
        format.html { render 'form' }
      end
    end
  end

  def destroy
    @client_category = find_record ClientCategory
    @client_category.destroy
    respond_to do |format|
      format.html { redirect_to client_categories_url }
    end
  end

  private

  def client_category_params
    params.require(:client_category).permit(:color, :name)
  end
end
