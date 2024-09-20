class DeviceInput < SimpleForm::Inputs::Base

  def input(wrapper_options=nil)
    content = ''
    content << template.content_tag(:span, template.glyph(:search), class: 'input-group-addon add-on')
    content << @builder.hidden_field("#{attribute_name}_id", class: 'item_id') unless disabled?
    content << template.text_field_tag(:item_search, presentation, class: "item_search form-control has-tooltip", placeholder: I18n.t('helpers.placeholders.item'), autocomplete: 'off', title: status_info, data: {html: true, container: 'body', status: status})
    content << template.link_to(template.glyph(:plus), template.new_device_path, class: 'new_item_btn btn btn-default', remote: true) unless disabled?
    content << template.link_to(template.glyph(:edit), device.present? ? template.edit_device_path(device) : '#', class: 'edit_item_btn btn btn-default', remote: device.present?) unless disabled?
    content << template.link_to(template.glyph('eye'), device.present? ? template.device_path(device) : '#', class: 'show_item_btn btn btn-default', remote: device.present?)
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
end
