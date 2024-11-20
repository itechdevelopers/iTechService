class SecurityCodeInput < SimpleForm::Inputs::StringInput

  def input(wrapper_options = nil)
    template.content_tag(:div, class: 'input-append') do
      input_field = @builder.input_field(attribute_name, class: 'input-large')
      dropdown = template.content_tag(:div, class: 'btn-group') do
        template.content_tag(:button,
                             I18n.t('service_jobs.security_codes.none'),
                             type: 'button',
                             class: 'btn btn-warning dropdown-toggle',
                             data: { toggle: 'dropdown' }) +
          template.content_tag(:ul, class: 'dropdown-menu') do
            security_code_options.map do |key, translation|
              template.content_tag(:li) do
                template.link_to(translation, '#',
                                 class: 'security-code-option',
                                 data: { value: key })
              end
            end.join.html_safe
          end
      end
      input_field + dropdown
    end.html_safe
  end


  private

  def security_code_options
    I18n.t('service_jobs.security_codes').symbolize_keys
  end

end
