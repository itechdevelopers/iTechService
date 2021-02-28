# frozen_string_literal: true

class ObjectInput < SimpleForm::Inputs::StringInput
  def input(wrapper_options = nil)
    merged_input_options = merge_wrapper_options(input_html_options, wrapper_options)

    t = template
    f = @builder
    content = t.content_tag(:span, id: 'object_selector') do
      t.content_tag(:div, class: 'input-prepend') do
        t.link_to(t.icon_tag(:search),
                  t.choose_products_path(
                    form: 'order',
                    association: '',
                    is_product_only: true,
                    parent_input_id: "#{f.object_name}_#{attribute_name}"
                  ),
                  class: 'btn', remote: true)
      end
    end
    content += f.text_field(attribute_name, merged_input_options)
    content.html_safe
  end
end
