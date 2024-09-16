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
      default_option + select_options
    end
  end

  def default_option
    @builder.template.content_tag(:span, placeholder_text, class: 'custom-option selected', data: { value: '', color: '' })
  end

  def select_options
    collection.map do |item|
      @builder.template.content_tag(:span, item_label(item),
                                    class: 'custom-option',
                                    data: {
                                      value: item_value(item),
                                      color: item_color(item)
                                    }
      )
    end.join.html_safe
  end

  def collection
    @collection ||= @options[:collection] || self.class.name.underscore.to_sym
  end

  def item_label(item)
    item.try(:name) || item.to_s
  end

  def item_value(item)
    item.try(:id) || item.to_s
  end

  def item_color(item)
    item.try(:color) || ''
  end

  def placeholder_text
    @options[:prompt] || 'Выберите задачу'
  end

  def selected_option
    @options[:selected_option] || ''
  end
end
