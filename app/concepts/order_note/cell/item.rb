module OrderNote::Cell
  class Item < BaseCell
    include Pundit::Authorization
    private

    property :author_color, :author_name, :content, :id

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
  end
end
