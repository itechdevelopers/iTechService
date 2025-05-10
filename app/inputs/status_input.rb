class StatusInput < SimpleForm::Inputs::Base

  def input(wrapper_options = nil)
    (@builder.hidden_field(:status) +
        template.content_tag(:span, class: 'btn-group') do
          template.content_tag(:button, id: 'status_select_button', class: 'btn dropdown-toggle',
                               'data-toggle' => 'dropdown') do
            template.content_tag(:span, id: 'status_value', class: 'pull-left') do
              @builder.object.status.blank? ? '-' : template.t("orders.statuses.#{@builder.object.status}").html_safe
            end +
                template.content_tag(:span, nil, class: 'caret pull-right')
          end +
              template.content_tag(:ul, id: 'statuses_list', class: 'dropdown-menu') do
                Order::NEW_STATUSES.map do |status|
                  template.content_tag(:li, template.link_to(template.t("orders.statuses.#{status}").html_safe, '#',
                                                             status: status))
                end.join.html_safe
              end
        end
    ).html_safe
  end

end
