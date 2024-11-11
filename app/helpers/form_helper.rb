module FormHelper

  def secondary_form_container
    content_tag :div, nil, id: 'secondary_form_container', class: 'form_container well well-small'
  end

  def secondary_form_close_button(size=nil)
    if size == :small
      name = glyph('times-circle')
      button_class = 'close'
    else
      name = t 'helpers.links.close'
      button_class = 'btn'
    end
    link_to name, '#', class: "pull-left #{button_class}", data: {behavior: 'close_secondary_form'}
  end

  def custom_select(form, attribute, collection, options = {})
    wrapper_class = options.delete(:wrapper_class) || 'custom-select-wrapper'
    select_class = options.delete(:class) || 'custom-select'
    trigger_class = options.delete(:trigger_class) || 'custom-select__trigger'
    prompt = options.delete(:prompt) || 'Выберите значение'
    data_attributes = options.delete(:data) || {}

    content_tag(:div, class: wrapper_class) do
      content_tag(:div, class: select_class, **options) do
        custom_select_trigger(prompt, trigger_class) +
          custom_select_options(collection, prompt)
      end +
        form.hidden_field(attribute, data: data_attributes)
    end
  end

  private

  def custom_select_trigger(prompt, trigger_class)
    content_tag(:div, class: trigger_class) do
      content_tag(:span, prompt)
    end
  end

  def custom_select_options(collection, prompt)
    content_tag(:div, class: 'custom-options') do
      collection_options(collection)
    end
  end

  def default_option(prompt)
    content_tag(:span, prompt, class: 'custom-option default selected', data: { value: '', color: '' })
  end

  def collection_options(collection)
    collection.map do |item|
      content_tag(:span,
                  class: 'custom-option',
                  data: {
                    value: item.id,
                    color: item.try(:color) || ''
                  }) do
        contents = image_tag(item.icon_mini.url, class: 'achievements-img-icon-mini')
        contents << "  #{item.name}"
        contents.html_safe
      end
    end.join.html_safe
  end
end
