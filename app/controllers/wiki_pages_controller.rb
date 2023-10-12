class WikiPagesController < ApplicationController
    before_action :set_page, only: %i[show edit update destroy]
    skip_after_action :verify_same_origin_request, only: :search

    def index
      @pages = authorize WikiPage.all
    end

    def show
     authorize @page
    end

    def new
      authorize WikiPage.new
      category = WikiPageCategory.new
      @page = WikiPage.new(wiki_page_category: category)
    end

    def edit
      authorize @page
    end

    def create
      @page = authorize WikiPage.new(wiki_page_params.merge(creator: current_user))

      if @page.save
        redirect_to @page
      else
        render :new
      end
    end

    def update
      authorize @page
      if @page.update(wiki_page_params.merge(updator: current_user))
        redirect_to @page
      else
        render :edit
      end
    end

    def destroy
      authorize @page
      @page.destroy
      redirect_to wiki_pages_path
    end

    def search
      authorize WikiPage
      @pages = WikiPage.search(searching_params)
      respond_to do |format|
        format.js
      end
    end

    private

    def set_page
      @page = WikiPage.find(params[:id])
    end

    def wiki_page_params
      params.require(:wiki_page).permit(:content, :title, :wiki_page_category_id, :senior, :title_filter,
       :wiki_page_category_filter, wiki_page_category_attributes: [:title])
    end

    def searching_params
      params.slice(:title_filter, :wiki_page_category_filter)
    end
end
