class WikiDocumentsController < ApplicationController
  before_action :set_page

  def create
    authorize @page
    @document = @page.documents.create(document_params)
    redirect_to @page
  end

  def destroy
    authorize @page
    @document = @page.documents.find(params[:id])
    @document.destroy
    redirect_to @page
  end

  private

  def set_page
    @page = WikiPage.find(params[:wiki_page_id])
  end

  def document_params
    params.require(:wiki_document).permit(:file)
  end
end