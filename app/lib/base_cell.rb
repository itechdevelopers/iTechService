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

  def icon_tag(name)
    "<i class='icon-#{name.to_s}'></i>".html_safe
  end

  def edited_by_tag(editable)
    last_edit = RecordEdit.where(editable: editable).order(updated_at: :desc).limit(1).first
    label = ""
    if last_edit.present?
      label = "Отредактировано #{last_edit.user.short_name} [#{l(last_edit.updated_at, format: :date_time)}]"
    end
    "<i>#{label}</i>"
  end
end
