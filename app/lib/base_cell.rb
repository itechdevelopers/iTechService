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

  def icon_tag(name, type = nil)
    white_class = type.to_s == 'white' ? 'icon-white' : ''
    color_class = type.to_s unless type.to_s == 'white'
    "<i class='fa fa-#{name.to_s} #{white_class} #{color_class}'></i>".html_safe
  end

  def edited_by_tag(editable)
    last_edit = RecordEdit.where(editable: editable).order(updated_at: :desc).limit(1).first
    label = ""
    if last_edit.present?
      label = "Отредактировано #{last_edit.user.short_name} [#{l(last_edit.updated_at, format: :date_time)}]"
    end
    "<i>#{label}</i>"
  end

  def note_history_tag(note)
    link_to(glyph(:time),
            record_edits_path(editable_type: note.class.to_s, editable_id: note.id.to_s),
            remote: true) if RecordEdit.any_edits?(note)
  end
end
