# frozen_string_literal: true

class WikiPageCategoriesController < ApplicationController
  before_action :find_category, only: [:show, :edit, :update, :destroy]
  before_action :authorize_wiki_category

  def index
    @categories = WikiPageCategory.page(params[:page])
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: @category }
    end
  end

  def new
    @category = authorize WikiPageCategory.new

    respond_to do |format|
      format.html
      format.json { render json: @category }
    end
  end

  def create
    @category = authorize WikiPageCategory.new(category_params)

    respond_to do |format|
      if @category.save
        format.html { redirect_to wiki_page_categories_path, notice: t('wiki.categories.created') }
        format.json { render json: @category, status: :created, location: @category }
      else
        format.html { render action: :new }
        format.json { render json: @category.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit

  end

  def update
    respond_to do |format|
      if @category.update_attributes(category_params)
        format.html { redirect_to wiki_page_categories_path, notice: t('wiki.categories.updated') }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @category.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @category.destroy

    respond_to do |format|
      format.html { redirect_to wiki_page_categories_path }
      format.json { head :no_content }
    end
  end

  private

  def category_params
    params.require(:wiki_page_category).permit(:title)
  end

  def find_category
    @category = find_record WikiPageCategory
  end

  def authorize_wiki_category
    authorize WikiPageCategory
  end
end
