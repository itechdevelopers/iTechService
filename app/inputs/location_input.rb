class LocationInput < SimpleForm::Inputs::Base
  delegate :content_tag, :link_to, :icon_tag, :locations_path, :current_user, to: :template

  def input(_wrapper_options = nil)
    content_tag(:div, id: 'location_input', class: 'dropdown-input') do
      @builder.hidden_field(attribute_name, id: 'location_id') +
        content_tag(:span, class: 'btn-group') do
          content_tag(:a, id: 'locations_select_button', class: 'btn dropdown-toggle', 'data-toggle' => 'dropdown') do
            content_tag(:span, id: 'location_value', class: 'pull-left') do
              @builder.object.location.blank? ? '-' : @builder.object.location.name
            end +
              content_tag(:span, nil, class: 'caret pull-right')
          end +
            content_tag(:ul, id: 'locations_list', class: 'dropdown-menu') do
              template.render 'locations/list', locations: locations, show_less_popular: true
            end +
            content_tag(:ul, id: 'departments_list', class: 'dropdown-menu hidden') do
              departments.map do |department|
                content_tag(:li,
                            link_to(department.full_name,
                                    locations_path(department_id: department.id, visible: true, popular: true),
                                    remote: true))
              end.join.html_safe
            end +
            content_tag(:ul, id: 'less_popular_list', class: 'dropdown-menu hidden') do
              template.render 'locations/list', locations: less_popular_locations, show_less_popular: false
            end
        end
    end.html_safe
  end

  private

  def user
    options.fetch(:user, template.current_user)
  end

  def locations
    Location.in_department(user.department).visible.popular.ordered
  end

  def less_popular_locations
    Location.visible.less_popular.ordered
  end

  def departments
    Department.selectable
  end
end