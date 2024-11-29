module OrderNote::Cell
  class Item < BaseCell
    include Pundit::Authorization
    private

    property :author_color, :author_name, :author, :content, :id, :notifications

    def author_name_link
      link_to author_name, user_path(author), style: "color: #{author_color};"
    end

    def element_id
      "order_note_" + id.to_s
    end

    def inline_form
      cell(OrderNote::Cell::InlineForm, model).()
    end

    def timestamp(time=nil)
      time = time.nil? ? model.created_at : time
      "[#{I18n.l(time, format: :date_time)}]"
    end

    def update_link
      if update?
        link_to icon_tag(:edit), "#", class: "form-inline-link", data: {form_inline_id: "order_note_#{model.id}"}
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
