module Comment::Cell
  class Preview < BaseCell
    include Pundit::Authorization
    private

    property :user_color, :user_name, :user, :content, :id, :notifications

    def user_name_link
      link_to user_name, user_path(user), style: "color: #{user_color};"
    end

    def element_id
      "comment_" + id.to_s
    end

    def inline_form
      cell(Comment::Cell::InlineForm, model).()
    end

    def timestamp(time=nil)
      time = time.nil? ? model.created_at : time
      "[#{I18n.l(time, format: :date_time)}]"
    end

    def update_link
      if update?
        link_to icon_tag(:edit), "#", class: "form-inline-link", data: {form_inline_id: "comment_#{model.id}"}
      end
    end

    def update?
      policy(model).update?
    end

    def edited_by_tag
      super(model)
    end

    def note_history_tag
      super(model)
    end

    def notified_users
      return "" unless users = model.notifications.map(&:user)
      users.map do |user| content_tag(:span,
        user.at_short_name,
        class: "notified-user-inline",
        style: "text-decoration-color: #{user.color}")
      end
      .join(', ')
      .html_safe
    end
  end
end
