module WikiPagesHelper
  def color_tag(category)
    content_tag(:div, "", 
                class: "wiki_color-tag change-colors-btn", 
                style: category_styles(category),
                data: {category: category.id}) do
      manage_colors_tag(category)
    end
  end

  def manage_colors_tag(category)
    content_tag(:div, class: "wiki_manage-colors-tags", data: {category: category.id}) do
      c = "".html_safe
      WikiPageCategory::WIKI_TAG_COLORS.each do |color|
        c += content_tag :div do
          button_to("",
                    wiki_page_category_path(category),
                    method: :put,
                    params: {wiki_page_category: {color_tag: color}},
                    remote: true,
                    style: "background-color: ##{color}",
                    class: "wiki_color-tag")
        end
      end
      c
    end
  end

  def wiki_category_tag_btn(category)
    button_to(category.title, 
              search_wiki_pages_path,
              method: :get,
              params: {wiki_page_category_filter: category.id},
              remote: true,
              class: 'wiki_tag btn-mini',
              data: {category: category.id},
              style: category_styles(category)
    )
  end

  def category_styles(category)
    styles = ""
    styles += "background-color: ##{category.color_tag};"
    styles += "color: #{category.matching_font_color};"
    styles += "border-color: #{category.matching_border_color};"
    styles
  end
end