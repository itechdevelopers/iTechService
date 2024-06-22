class DoneStatusInput < SimpleForm::Inputs::Base

  def input(wrapper_options = nil)
    template.content_tag(:div, class: 'done_status btn-group', 'data-toggle' => 'buttons-radio') do
      template.link_to(template.icon_tag('square-o'), '#', 'data-value' => 0, class: "btn #{'active' if @builder.object.pending?}") +
      template.link_to(template.icon_tag('check'), '#', 'data-value' => 1, class: "btn #{'active' if @builder.object.done?}") +
      template.link_to(template.icon_tag('minus-square-o'), '#', 'data-value' => 2, class: "btn #{'active' if @builder.object.undone?}")
    end +
    @builder.hidden_field(attribute_name)
  end

end