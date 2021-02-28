# lib/components/numbers_component.rb
module ClearButtonsComponent
  # To avoid deprecation warning, you need to make the wrapper_options explicit
  # even when they won't be used.
  def clear_button(wrapper_options = nil)
    content_tag(:i, '', class: 'icon-remove')
  end
end

SimpleForm::Inputs::Base.include(ClearButtonsComponent)
