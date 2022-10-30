class FewRemnantsReport < BaseReport
  attr_accessor :kind, :product_group_id, :show_code

  params %i[department_id product_group_id show_code]

  def name
    "#{super}_#{kind}"
  end

  def base_name
    'few_remnants'
  end

  def call
    result[:stores] = {}
    result[:products] = {}
    products = Product.send(kind)
    products = products.in_group(product_group_id) if product_group_id.present?
    stores = Store.visible
                  .send(kind == 'goods' ? :retail : :spare_parts)
                  .order('id asc')
    stores = stores.in_department(department) if department
    stores.each do |store|
      result[:stores].store store.id.to_s, { code: store.code, name: store.name }
    end
    products.each do |product|
      remnants = {}
      stores.each do |store|
        if product.quantity_threshold.present? &&
          (qty = product.quantity_in_store(store)) <= product.quantity_threshold
          remnants.store store.id.to_s, qty
        end
      end
      unless remnants.empty?
        result[:products].store product.id.to_s, { code: product.code, name: product.name, threshold: product.quantity_threshold, remnants: remnants }
      end
    end
    result
  end

  def show_code?
    show_code == '1'
  end

  def only_day?
    true
  end

  def product_groups_collection
    return [] unless kind == 'spare_parts'

    ProductGroup.spare_parts.at_depth(1).map { |product_group| [product_group.name, product_group.id] }
  end
end
