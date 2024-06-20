module ModelCell

  def self.included(base)
    base.class_eval do
      property :model_name
    end
  end

  def t_attribute(name)
    model_class.human_attribute_name name
  end

  def model_class
    model_name.name.constantize
  end

  def link_to_show(options = {})
    options.merge! class: 'btn'
    name = t 'show'
    link_to "#{icon(:eye)} #{name}".html_safe, model, options
  end

  def link_to_show_small(options = {})
    options.merge! class: 'btn btn-small'
    link_to icon('eye'), model, options
  end

  def link_to_edit(options = {})
    options.merge! class: 'btn'
    name = t 'edit'
    link_to url_for(controller: model.model_name.route_key, action: 'edit', id: model.id), options do
      "#{icon(:edit)} #{name}".html_safe
    end
  end

  def link_to_edit_small(options = {})
    options.merge! class: 'btn btn-small'
    link_to icon(:edit), url_for(controller: model.model_name.route_key, action: 'edit', id: model.id), options
  end
end