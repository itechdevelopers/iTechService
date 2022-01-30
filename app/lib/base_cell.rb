class BaseCell < Trailblazer::Cell
  def params
    controller.action_params
  end

  private

  include GlyphHelper
  # include FontAwesome::Sass::Rails::ViewHelpers
  # include Devise::Controllers::Helpers
  include ActionView::Helpers::TranslationHelper
  include Cell::Translation
  include LinksHelper
  include CommentsHelper

  delegate :view_context, :controller_name, :action_name, :current_user, :policy, to: :controller

  alias_method :icon, :glyph

  def title
    t '.title'
  end

  def superadmin?
    current_user.superadmin?
  end

  def comments_list
    comments_list_for model
  end

  def comment_form
    comment_form_for model
  end
end
