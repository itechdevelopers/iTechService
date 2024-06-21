module FormHelper

  def secondary_form_container
    content_tag :div, nil, id: 'secondary_form_container', class: 'form_container well well-small'
  end

  def secondary_form_close_button(size=nil)
    if size == :small
      name = glyph('times-circle')
      button_class = 'close'
    else
      name = t 'helpers.links.close'
      button_class = 'btn'
    end
    link_to name, '#', class: "pull-left #{button_class}", data: {behavior: 'close_secondary_form'}
  end
end
