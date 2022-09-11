class DatetimeQuickSelectInput < SimpleForm::Inputs::Base

  def input(wrapper_options = nil)
    template.content_tag(:div, class: 'datetimepicker datetime_quick_select input-append') do
      @builder.input_field(attribute_name, as: :string) +
      template.content_tag(:span, template.content_tag(:i, nil, {data: {time_icon: 'icon-time', date_icon: 'icon-calendar'}}), class: 'add-on') +
      template.content_tag(:div, class: 'btn-group') do
        template.content_tag(:button, "#{I18n.t('in_time')} #{template.caret_tag}".html_safe, class: 'btn dropdown-toggle', 'data-toggle' => 'dropdown') +
        template.content_tag(:ul, class: 'dropdown-menu') do
          template.content_tag(:li, template.link_to(I18n.t('datetime_select.x_minutes', count: 30), '#', class: 'time_link', 'data-value' => 30.minutes.since.strftime('%d.%m.%Y %H:%M'))) +
          1.upto(5).map do |h|
            template.content_tag(:li, template.link_to(I18n.t('datetime_select.x_hours', count: h), '#', class: 'time_link', 'data-value' => h.hours.since.strftime('%d.%m.%Y %H:%M')))
          end.join.html_safe +
          [3, 5, 7, 14, 45].map do |d|
            template.content_tag(:li, template.link_to(I18n.t('datetime_select.x_days', count: d), '#', class: 'time_link', 'data-value' => d.days.since.strftime('%d.%m.%Y %H:%M')))
          end.join.html_safe
        end
      end
    end
  end

end