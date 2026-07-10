# frozen_string_literal: true

module PackageDesignsHelper
  # Ячейка «Дизайн»: миниатюра (если загружена) + название.
  def design_cell(design)
    thumb = image_tag(design.image.thumb.url, class: 'package-design-thumb') if design.image?
    safe_join([thumb, content_tag(:div, design.name)].compact)
  end
end
