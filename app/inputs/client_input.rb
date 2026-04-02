class ClientInput < SimpleForm::Inputs::StringInput

  def input(wrapper_options = nil)
    (
    template.content_tag(:div, id: 'client_input', class: 'input-prepend input-append') do
      search_value = client&.presentation || template.params[:client]
      template.content_tag(:span, template.icon_tag(:search), class: 'add-on') +
      if client.is_a?(Client)
        template.text_field_tag(:client_search, search_value, placeholder: template.t('client_input_placeholder').html_safe, autofocus: true, autocomplete: 'off', style: "color: #{client&.category_color}", class: 'has-tooltip', title: client&.work_algorithm, data: {html: true, container: 'body'})
      else
        template.text_field_tag(:client_search, search_value, placeholder: template.t('client_input_placeholder').html_safe, autofocus: true, autocomplete: 'off')
      end +
      @builder.hidden_field("#{attribute_name}_id", id: 'client_id', class: 'client_id') +
      template.link_to(template.icon_tag(:plus), template.new_client_path, id: 'new_client_link', class: 'btn', remote: true) +
      template.link_to(template.icon_tag(:edit), client.present? ? template.edit_client_path(client) : '#', id: 'edit_client_link', class: 'btn', remote: client.present?) +
      transfer_link(options[:transfer])
    end +
    template.content_tag(:ul, id: 'clients_autocomplete_list', class: 'dropdown-menu') do
      template.clients_autocomplete_list
    end +
    if options[:no_devices]
      ''
    else
      template.content_tag(:div, id: 'client_devices', class: 'popover fade right in') do
        template.content_tag(:div, nil, class: 'arrow') +
        template.content_tag(:div, class: 'popover-inner') do
          template.content_tag(:h3, class: 'popover-title') do
            I18n.t('service_jobs.client_devices').html_safe +
            template.content_tag(:span, id: 'client_devices_resize_button', href: '#') do
              template.icon_tag('sort')
            end
          end +
          template.content_tag(:div, class: 'popover-content') do
            template.client_devices_list(client)
          end
        end
      end
    end
    ).html_safe
  end

  private

  def client
    return @client if defined? @client

    @client = @builder.object.client || Client.find_by(id: @builder.object.client_id)
  end

  def transfer_link(transfer)
    template.link_to(I18n.t('helpers.links.to_reception'), template.new_service_job_path, class: 'btn btn-link', id: 'client_transfer_link') if transfer
  end
end