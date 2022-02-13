module IndexCell
  def self.included(base)
    base.class_eval do
      private

      include ModelCell
      property :model_name
      alias_method :collection, :model
    end
  end

  private

  def new_link(**options)
    options[:class] = 'btn btn-success btn-large'
    name ||= I18n.t("#{model_name.collection}.new.title", default: t('new'))
    link_to url_for(controller: model_name.route_key, action: 'new'), options do
      "#{icon(:plus)} #{name}".html_safe
    end
  end

  def nothing_found_message
    content_tag :h2, I18n.t('errors.nothing_found')
  end

  def sortable_column(column)
    title = t_attribute(column)

    if column.to_s == sort_column
      css_class = "current #{sort_direction} nav nav-pills"
      direction = sort_direction == 'asc' ? 'desc' : 'asc'
      icon_name = (sort_direction == 'asc') ? 'caret-up' : 'caret-down'
    else
      css_class = 'nav nav-pills'
      icon_name = 'sort'
      direction = 'asc'
    end
    title = "#{title} #{icon(icon_name)}".html_safe
    attr = params.permit!.to_h
    link_to title, attr.merge(sort_column: column, sort_direction: direction, page: nil), {class: css_class, remote: true}
  end

  def sort_column
    params.fetch(:sort_column, '')
  end

  def sort_direction
    params.fetch(:sort_direction, 'asc')
  end
end
