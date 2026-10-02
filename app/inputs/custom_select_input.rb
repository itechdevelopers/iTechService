class CustomSelectInput < SimpleForm::Inputs::Base
  def input(wrapper_options = nil)
    merged_input_options = merge_wrapper_options(input_html_options, wrapper_options)

    @builder.template.content_tag(:div, class: 'custom-select-wrapper') do
      @builder.template.content_tag(:div, class: 'custom-select', **merged_input_options) do
        trigger + select_options_container
      end +
        @builder.hidden_field(attribute_name, value: selected_option)
    end
  end

  private

  def trigger
    @builder.template.content_tag(:div, class: 'custom-select__trigger') do
      @builder.template.content_tag(:span, placeholder_text)
    end
  end

  def select_options_container
    @builder.template.content_tag(:div, class: 'custom-options') do
      search_field + default_option + select_options
    end
  end

  # Free-text filter over the options, opt-in per form via `searchable: true`.
  # The field carries no `name`, so it never reaches params — filtering is
  # purely client-side over the already rendered options.
  def search_field
    return ''.html_safe unless searchable?

    @builder.template.content_tag(:div, class: 'custom-select__search') do
      @builder.template.tag(:input, type: 'text',
                                    class: 'custom-select__search-input',
                                    placeholder: search_placeholder,
                                    autocomplete: 'off')
    end
  end

  def searchable?
    @options[:searchable].present?
  end

  def search_placeholder
    @options[:search_placeholder] || I18n.t('helpers.placeholders.search')
  end

  def default_option
    @builder.template.content_tag(:span, placeholder_text, class: 'custom-option selected', data: { value: '', color: '' })
  end

  def select_options
    collection.map do |item|
      @builder.template.content_tag(:span, item_label(item),
                                    class: item_classes(item),
                                    data: {
                                      value: item_value(item),
                                      color: item_color(item),
                                      emoji: item.try(:emoji).presence
                                    }
      )
    end.join.html_safe
  end

  # Emoji, boldness and row size exist only on Task: for the other collections (employees in
  # faults, merits, uniform issues) `try` returns nil and the option stays plain.
  # The emoji goes to data-emoji rather than into the label: CSS draws it as a pseudo-element,
  # and the intake JS recognises the "Ремонт" task by the option's .text().
  def item_classes(item)
    classes = ['custom-option']
    classes << 'custom-option--bold' if item.try(:bold)
    row_size = item.try(:row_size)
    classes << "custom-option--#{row_size}" if row_size.present? && row_size != 'normal'
    classes
  end

  def collection
    @collection ||= @options[:collection] || self.class.name.underscore.to_sym
  end

  def item_label(item)
    method = @options[:label_method]
    return item.public_send(method).to_s if method

    item.try(:name) || item.to_s
  end

  def item_value(item)
    method = @options[:value_method]
    return item.public_send(method).to_s if method

    item.try(:id) || item.to_s
  end

  def item_color(item)
    method = @options[:color_method] || :color
    item.try(method) || ''
  end

  def placeholder_text
    @options[:prompt] || 'Выберите задачу'
  end

  def selected_option
    @options[:selected_option] || @builder.object.try(:send, attribute_name) || ''
  end
end
