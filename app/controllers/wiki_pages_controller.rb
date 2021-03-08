# frozen_string_literal: true

class WikiPagesController < ApplicationController
  skip_after_action :verify_authorized
  acts_as_wiki_pages_controller

  private

  def show_allowed?
    policy(WikiPage).read?
  end

  def history_allowed?
    policy(WikiPage).manage?
  end

  def edit_allowed?
    policy(WikiPage).manage?
  end

  def wiki_page_params
    params.require(:wiki_page)
          .permit(:content, :creator_id, :path, :title, :updator_id)
  end
end
