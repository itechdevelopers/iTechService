class ImagesController < ApplicationController
  before_action :set_wiki_page

  def create
    authorize @wiki_page
    @wiki_page.images += images_params[:images]
    @wiki_page.save!
    redirect_to edit_wiki_page_url(@wiki_page)
  end

  def destroy
    authorize @wiki_page
    deleted_img = @wiki_page.images.delete_at(params[:id].to_i)
    File.delete(deleted_img.path)
    @wiki_page.save!
    redirect_to edit_wiki_page_url(@wiki_page)
  end

  private

  def set_wiki_page
    @wiki_page ||= WikiPage.find(params[:wiki_page_id])
  end

  def images_params
    params.require(:wiki_page).permit(images: [])
  end
end
