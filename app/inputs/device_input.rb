class DeviceInput < SimpleForm::Inputs::Base

  def input(wrapper_options=nil)
    content = ''
    device_input_content = template.content_tag(:div, class: 'device-input-container') do
      input_content = ''
      input_content << template.content_tag(:span, template.glyph(:search), class: 'input-group-addon add-on')
      input_content << @builder.hidden_field("#{attribute_name}_id", class: 'item_id') unless disabled?
      if multiline?
        input_content << template.text_area_tag(:item_search, multiline_presentation,
          class: "item_search form-control has-tooltip",
          placeholder: I18n.t('helpers.placeholders.item'),
          autocomplete: 'off',
          title: status_info,
          data: {html: true, container: 'body', status: status},
          rows: 3)
      else
        input_content << template.text_field_tag(:item_search, presentation, class: "item_search form-control has-tooltip", placeholder: I18n.t('helpers.placeholders.item'), autocomplete: 'off', title: status_info, data: {html: true, container: 'body', status: status})
      end
      input_content << template.link_to(template.glyph(:plus), template.new_device_path, class: 'new_item_btn btn btn-default', remote: true) unless disabled?
      input_content << template.link_to(template.glyph(:edit), device.present? ? template.edit_device_path(device) : '#', class: 'edit_item_btn btn btn-default', remote: device.present?) unless disabled?
      input_content << template.link_to(template.glyph('eye'), device.present? ? template.device_path(device) : '#', class: 'show_item_btn btn btn-default', remote: device.present?)
      input_content.html_safe
    end

    content << device_input_content
    content << template.content_tag(:div, '', class: 'device_1c_status')

    template.content_tag(:div, content.html_safe, class: "device_input input-group input-append input-prepend")
  end

  private

  def device
    return @device if defined? @device

    @device = @builder.object.item || Item.find_by(id: @builder.object.item_id)
  end

  def device_presenter
    device&.decorate
  end

  def status
    device_presenter&.status
  end

  def status_info
    device_presenter&.status_info
  end

  def presentation
    device_presenter&.presentation
  end

  def disabled?
    options[:disabled] == true
  end

  def multiline?
    options[:multiline] == true
  end

  def multiline_presentation
    return nil unless device_presenter
    [device_presenter.name, device_presenter.serial_number, device_presenter.imei].join("\n")
  end
end
