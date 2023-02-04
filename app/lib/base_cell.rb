class BaseCell < Trailblazer::Cell
  private

  include GlyphHelper
  # include FontAwesome::Sass::Rails::ViewHelpers
  # include Devise::Controllers::Helpers
  include ActionView::Helpers::TranslationHelper
  include Cell::Translation
  include LinksHelper
  include CommentsHelper

  delegate :view_context, :controller_name, :action_name, :params, :current_user, :policy, to: :controller
  delegate :superadmin?, :able_to?, to: :current_user

  alias_method :icon, :glyph

  def title
    t '.title'
  end

  def comments_list
    comments_list_for model
  end

  def comment_form
    comment_form_for model
  end
end
