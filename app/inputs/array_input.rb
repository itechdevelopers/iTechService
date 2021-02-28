# frozen_string_literal: true

class ArrayInput < SimpleForm::Inputs::StringInput
  def input
    input_html_options[:type] ||= input_type

    t = template
    c = t.content_tag(:div, id: "#{attribute_name}_list") do
      Array(object.public_send(attribute_name)).map do |array_el|
        input_element(array_el)
        # @builder.text_field(nil, input_html_options.merge(value: array_el, name: "#{object_name}[#{attribute_name}][]"))
      end.join.html_safe
    end

    c += template.link_to 'Add Wish', "##{attribute_name}_list",
                          class: "add_#{attribute_name}_fields",
                          "data-field": input_element('')
    c
  end

  def input_element(value)
    template.content_tag(:p) do
      @builder.text_field(nil, input_html_options.merge(value: value, name: "#{object_name}[#{attribute_name}][]"))+
        template.content_tag(:span, class: 'btn_orange') do
          template.content_tag(:a, href: '#', class: 'remove_field') { 'x' }
        end
    end.html_safe
  end

  def input_type
    :text
  end
end
