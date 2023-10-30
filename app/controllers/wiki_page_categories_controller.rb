# frozen_string_literal: true

class WikiPageCategoriesController < ApplicationController
  before_action :set_category

  def destroy
    @category.wiki_pages.update_all(wiki_page_category_id: nil)
    @category.destroy
  end

  def update
    @category.update(category_params)
    respond_to do |format|
      format.js
    end
  end

  private
  
  def set_category
    @category = authorize WikiPageCategory.find(params[:id])
  end

  def category_params
    params.require(:wiki_page_category).permit(:title, :color_tag)
  end
end
