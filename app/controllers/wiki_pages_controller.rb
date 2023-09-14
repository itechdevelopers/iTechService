# frozen_string_literal: true

class WikiPagesController < ApplicationController
  skip_after_action :verify_authorized
  before_action :find_wiki_page, only: [:show, :edit, :update, :destroy, :history]
  before_action :categories, only: [:index, :new, :edit, :search]
  before_action :find_category, only: [:index, :search]

  def index
    wiki_pages = params[:private] ? WikiPage.is_private : WikiPage.is_common
    wiki_pages = wiki_pages.by_category(params[:category_id]) if params[:category_id]

    @wiki_pages = wiki_pages.page(params[:page])
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: @wiki_page }
    end
  end

  def new
    @wiki_page = authorize WikiPage.new

    respond_to do |format|
      format.html
      format.json { render json: @wiki_page }
    end
  end

  def create
    @wiki_page = authorize WikiPage.new(wiki_page_params)

    respond_to do |format|
      if @wiki_page.save
        create_version(1, params[:comment])

        format.html { redirect_to wiki_pages_path, notice: t('wiki.created') }
        format.json { render json: @wiki_page, status: :created, location: @wiki_page }
      else
        format.html { render action: :new }
        format.json { render json: @wiki_page.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit; end

  def update
    respond_to do |format|
      if @wiki_page.update_attributes(wiki_page_params)
        create_version(@wiki_page.versions.last.number + 1, params[:comment]) if params[:comment].present?

        format.html { redirect_to wiki_pages_path, notice: t('wiki.updated') }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @wiki_page.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @wiki_page.destroy

    respond_to do |format|
      format.html { redirect_to wiki_pages_path }
      format.json { head :no_content }
    end
  end

  def history; end

  def search
    value = "%#{params[:search]}%" if params[:search].present?
    wiki_pages = params[:private].present? ? WikiPage.is_private : WikiPage.is_common
    wiki_pages = wiki_pages.by_category(params[:category_id]) if params[:category_id].present?
    @wiki_pages = wiki_pages.where("title ILIKE ? or content ILIKE ?", value, value).page(params[:page])

    respond_to do |format|
      format.html
      format.json { render json: @wiki_page }
    end
  end

  private

  def wiki_page_params
    params.require(:wiki_page)
          .permit(:content, :creator_id, :path, :title, :updator_id, :private, :wiki_page_category_id)
  end

  def find_wiki_page
    wiki_page_path = action_name == 'history' ? params[:format] : params[:path]
    @wiki_page = WikiPage.find_by(path: wiki_page_path)
  end

  def show_allowed?
    policy(WikiPage).read?
  end

  def history_allowed?
    policy(WikiPage).manage?
  end

  def edit_allowed?
    policy(WikiPage).manage?
  end

  def create_version(number, comment)
    WikiPageVersion.create(
      page_id: @wiki_page.id,
      updator_id: current_user.id,
      number: number,
      comment: comment,
      path: @wiki_page.path,
      title: @wiki_page.title,
      content: @wiki_page.content,
    )
  end

  def categories
    @categories = WikiPageCategory.all
  end

  def find_category
    @category = WikiPageCategory.find(params[:category_id]) if params[:category_id]
  end
end
