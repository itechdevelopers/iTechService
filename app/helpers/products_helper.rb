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

end
