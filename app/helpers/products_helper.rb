module ProductsHelper

  def product_items(products)
    if products.any?
      products.map do |product|
        content_tag(:li, link_to(product.name, '#'))
      end.join.gsub('\n', '')
    else
      ''
    end
  end

  def product_select_list
    if ProductGroup.roots.goods.any?
      product_group = ProductGroup.roots.goods.first.subtree
      product_groups_tree_tag(product_group)
    else
      nil
    end
  end

  def remains_presentation(product, store)
    if product.present? and store.present?
      "#{product.quantity_in_store(store)} (#{product.quantity_in_store})"
    elsif product.present?
      "#{product.quantity_in_store}"
    else
      '-'
    end
  end

  def link_to_add_product(form, association, is_product_only, options={})
    link_to "#{glyph(:plus)} #{t('products.add_product')}".html_safe, choose_products_path(form: form, association: association, is_product_only: is_product_only, options: options), remote: true, class: 'btn btn-success'
  end

  def product_fields(form, association, object, options={})
    form ||= 'sale'
    association ||= 'sale_items'
    partial_name = "#{form.tableize}/#{association.singularize}_fields"
    parent = form.classify.constantize.new
    reflection = parent.class.reflect_on_association(association.to_sym)
    if reflection.present?
      object_class = reflection.klass
      attributes = {object.class.to_s.foreign_key => object.send(reflection.options[:primary_key] || :id)}
      new_object = object_class.new attributes
      form_for(parent) do |f|
        f.simple_fields_for(association, new_object, child_index: object.id) do |ff|
          return render(partial_name, f: ff, options: options)
        end
      end
    else
      nil
    end
  end

  def link_to_product_quick_select(product)
    link_to product.name, choose_products_path(product_id: product.id, form: 'sale', association: 'sale_items'), remote: true, title: product.name, class: 'product_quick_select_link'
  end

  def product_photo_gallery_mini(product)
    default_res = content_tag(:span, "Нет фотографий", class: "no-photos")
    return default_res unless product.photos.present?
    
    content_tag(:div, class: "photo-gallery-mini", data: { product_id: product.id }) do
      div_html = ""
      product.photos.each_with_index do |photo, index|
        one = index == 0 ? true : false
        two = index == 1 ? true : false
        div_html += content_tag(:div, class: "mini-photo #{'mini-chosen-one' if one} #{'mini-chosen-two' if two}", data: { product_id: product.id }) do
          res = ""
          res += link_to image_tag(photo.thumb.file.authenticated_url(expires_in: 600)), product_photo_path(product, index), data: { remote: true }, title: "#{index + 1}/#{product.photos.count}"
          res += link_to product_photo_path(product, index), method: :delete, data: { confirm: 'Вы уверены?' }, class: "delete-photo" do "#{glyph(:trash)}".html_safe; end
          res.html_safe
        end
      end
      div_html.html_safe
    end
  end

  def product_photo_gallery(photos, chosen_photo_id, photos_data)
    gallery_html = []
    gallery_html << content_tag(:div, "", class: "btn-gallery-left")
    gallery_html << content_tag(:div, class: "gallery") do
      div_html = ""
      photos.each_with_index do |photo, index|
        div_html += content_tag(:div, class: "photo #{'chosen' if index == chosen_photo_id}") do
          content_tag(:span, class: "photo-index") do
            if photos_data.present? && photos_data[index].present?
              user_name = JSON.parse(photos_data[index].gsub(/:([a-zA-z]+)/,'"\\1"').gsub('=>', ': '))["user"]
              date = JSON.parse(photos_data[index].gsub(/:([a-zA-z]+)/,'"\\1"').gsub('=>', ': '))["date"]
              "Добавлено #{user_name}<br>#{date}".html_safe
            else
              "".html_safe
            end
          end +
          content_tag(:img, "", src: photo.file.authenticated_url(expires_in: 600)).html_safe
        end
      end
      div_html.html_safe
    end
    gallery_html << content_tag(:div, "", class: "btn-gallery-right")
    gallery_html.join.html_safe
  end

end
