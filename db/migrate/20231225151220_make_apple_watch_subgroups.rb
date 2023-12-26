class MakeAppleWatchSubgroups < ActiveRecord::Migration[5.1]
  def up
    watch_group = ProductGroup.find_by(name: "Apple Watch")
    series_type = OptionType.find_by(name: "Серия Apple Watch")
    series_type.option_values.each do |series|
      ProductGroup.create!(name: series.name, code: series.name, parent_id: watch_group.id)
    end
    watch_group.products.each do |product|
      next unless product.options.find_by(option_type_id: series_type.id).present?
      series_name = product.options.find_by(option_type_id: series_type.id).name
      product_group = ProductGroup.find_by(name: series_name)
      product.update(product_group_id: product_group.id)
    end
  end

  def down
    watch_group = ProductGroup.find_by(name: "Apple Watch")
    watch_group.children.each do |child|
      child.products.each do |product|
        product.update(product_group_id: watch_group.id)
      end
      child.destroy
    end
  end
end
