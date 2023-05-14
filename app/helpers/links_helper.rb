module LinksHelper
  def link_back_to(options)
    link_to icon('chevron-left'), url_for(options), class: 'link_back'
  end

  def link_back_to_index(options = {})
    options.merge! action: 'index', controller: controller_name
    link_to icon('chevron-left'), url_for(options), class: 'link_back'
  end
end
