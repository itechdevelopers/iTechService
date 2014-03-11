class ProductImport
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  include ActiveModel::Validations

  attr_accessor :file, :store_id, :prices_file, :barcodes_file

  def initialize(attributes = {})
    attributes.each { |name, value| send("#{name}=", value) }
  end

  def persisted?
    false
  end

  def save
    time_format = "%Y.%m.%d %H:%M:%S"
    import_time = Time.current
    import_log << ['info', "Import started at [#{import_time.strftime(time_format)}]"]
    if file.present?
      if imported_products.map(&:valid?).all?
        imported_products.each &:save
        imported_count = imported_products.count
        import_log << ['success', "Imported #{imported_count.to_s + " product".pluralize(imported_count)}"]
        import_log << ['info', "Import finished at [#{Time.current.strftime(time_format)}]"]
        true
      else
        imported_products.each_with_index do |product, index|
          product.errors.full_messages.each do |message|
            errors.add :base, "Row #{index+1} [code #{product.code}]: #{message}"
          end
        end
        false
      end
    elsif prices_file.present?
      if imported_batches.map(&:valid?).all?
        imported_batches.each &:save!
        imported_count = imported_batches.count
        import_log << ['success', "Imported #{imported_count.to_s + " batches".pluralize(imported_count)}"]
        import_log << ['info', "Import finished at [#{Time.current.strftime(time_format)}]"]
        true
      else
        imported_batches.each_with_index do |batch, index|
          batch.errors.full_messages.each do |message|
            errors.add :base, "Row #{index+1} [code #{batch.code}]: #{message}"
          end
        end
        false
      end
    elsif barcodes_file.present?
      if imported_barcodes.map(&:valid?).all?
        imported_barcodes.each &:save!
        imported_count = imported_barcodes.count
        import_log << ['success', "Imported #{imported_count.to_s + " barcodes".pluralize(imported_count)}"]
        import_log << ['info', "Import finished at [#{Time.current.strftime(time_format)}]"]
        true
      else
        imported_barcodes.each_with_index do |barcode, index|
          barcode.errors.full_messages.each do |message|
            errors.add :base, "Row #{index+1} [barcode #{barcode.barcode_num}]: #{message}"
          end
        end
        false
      end
    end
  end

  def load_imported_products
    sheet = FileLoader.open_spreadsheet file
    store = Store.find store_id
    products = []
    product_group = parent_id = product = nil
    (6..sheet.last_row-1).each do |i|
      row = sheet.row i
      import_log << ['inverse', "#{i} #{'-'*140}"]
      import_log << ['info', row]
      if (code = row[0][/\d+(?=.\|)/]).present?
        name = row[0][/(?<=\|\s).+(?=,)/]
        if row[10].blank?
          parent_id = product_group.id if product_group.present? and product_group.is_root?
          product_group = ProductGroup.find_or_create_by_code(code: code, name: name, parent_id: parent_id)
        elsif product_group.present? and name.present?
          unless (product = Product.find_by_code(code)).present?
            next_row = sheet.row i+1
            product_attributes = {code: code, name: name, product_group_id: product_group.id}
            if next_row[0].length > 3
              if next_row[0] =~ /,/
                product_attributes.merge! product_category_id: ProductCategory.equipment_with_imei.id
              else
                product_attributes.merge! product_category_id: ProductCategory.accessory_with_sn.id if product_group.is_accessory
              end
            end
            product = Product.new product_attributes
            products << product
            import_log << ['success', 'New product: ' + product_attributes.inspect]
          end
          # Purchase Price
          purchase_price = product.prices.build price_type_id: PriceType.purchase.id, value: row[10], date: import_time
          import_log << ['success', 'New purchase Product Price: ' + purchase_price.inspect]
          # Retail Price
          retail_price = product.prices.build price_type_id: PriceType.retail.id, value: row[11], date: import_time
          import_log << ['success', 'New retail Product Price: ' + retail_price.inspect]
        end
      elsif (quantity = row[5].to_i) > 0 and product.present?
        # Item
        if row[0].length > 3
          features = row[0].split ', '
          if (item = Item.search(q: features[0]).first).present?
            import_log << ['info', 'Item already present: ' + features.inspect]
          else
            if features.length == 2
              item = product.items.build features_attributes: {0 => {feature_type_id: FeatureType.serial_number.id, value: features[0]}, 1 => {feature_type_id: FeatureType.imei.id, value: features[1]}}
            else
              item = product.items.build features_attributes: {0 => {feature_type_id: FeatureType.serial_number.id, value: features[0]}}
            end
            import_log << ['success', 'New item: ' + features.inspect]
          end
        else
          unless (item = product.items.first).present?
            item = product.items.build
            import_log << ['success', 'New item: ' + item.inspect]
          end
        end

        # Store Items
        store_item_attributes = {store_id: store.id, quantity: quantity}
        if (store_item = (item.feature_accounting) ? item.store_items.first : item.store_items.in_store(store).first).present?
          store_item.attributes = store_item_attributes
          import_log << ['success', 'Update Store Item: ' + store_item.inspect]
        else
          store_item = item.store_items.build store_item_attributes
          import_log << ['success', 'New Store Item: ' + store_item.inspect]
        end
      end
    end
    import_log << ['inverse', '-'*160]
    products
  end

  def load_imported_batches
    sheet = FileLoader.open_spreadsheet prices_file
    batches = []
    (9..sheet.last_row-1).each do |i|
      row = sheet.row i
      import_log << ['inverse', "#{i} #{'-'*140}"]
      import_log << ['info', row]
      unless row[0].to_s[/\d+.\|/]
        sn = row[0].to_s[/[^,]+/]
        if (item = Item.search(q: sn).first).present?
          price = row[3]
          batch = item.batches.build quantity: 1, price: row[3]
          batches << batch
          import_log << ['info', 'Purchase price: ' + price.inspect]
          import_log << ['success', 'New Batch: ' + batch.inspect]
        end
      end
    end
    batches
  end

  def load_imported_barcodes
    sheet = FileLoader.open_spreadsheet barcodes_file
    barcodes = []
    (2..sheet.last_row).each do |i|
      row = sheet.row i
      import_log << ['inverse', "#{i} #{'-'*140}"]
      import_log << ['info', row]
      barcode = row[0].to_i.to_s
      if barcode.length == 13 && barcode.start_with?('242')
        name = row[1]
        sn = row[2].to_s[/[^,]+/]
        if (item = Item.search(q: sn || name).first).present?
          item.barcode_num = barcode
          barcodes << item
          import_log << ['success', 'New barcode: ' + item.inspect]
        else
          import_log << ['warning', 'Item not found: ' + (sn || name)]
        end
      end
    end
    barcodes
  end

  def imported_products
    @imported_products ||= load_imported_products
  end

  def imported_items
    @imported_items ||= []
  end

  def imported_store_items
    @imported_store_items ||= []
  end

  def imported_product_prices
    @imported_product_prices ||= []
  end

  def imported_batches
    @imported_batches ||= load_imported_batches
  end

  def imported_barcodes
    @imported_barcodes ||= load_imported_barcodes
  end

  def import_log
    @import_logs ||= []
  end

  def import_time
    @import_time ||= Time.current
  end
  #
  #def imported_products
  #  @imported_products ||= load_imported_products[:products]
  #end
  #
  #def imported_items
  #  @imported_items ||= load_imported_products[:items]
  #end
  #
  #def imported_store_items
  #  @imported_store_items ||= load_imported_products[:store_items]
  #end
  #
  #def imported_product_prices
  #  @imported_product_prices ||= load_imported_products[:product_prices]
  #end

  #def load_imported
  #  sheet = open_spreadsheet
  #  products = []
  #  shop_cols = [4, 8]
  #  shops = []
  #  shop_cols.each do |col|
  #    if (shop = Shop.find_by_name sheet.cell(4, col)).present?
  #      shops << shop
  #    end
  #  end
  #  (6..sheet.last_row-1).each do |i|
  #    row = sheet.row i
  #    import_log << ['inverse', "#{i} #{'-'*140}"]
  #    import_log << ['info', row]
  #    unless (code_1c = row[0][/\d+/]).blank?
  #      if (product = Product.find_by_code_1c(code_1c)).present?
  #        new_attributes = {}
  #        new_attributes.merge! price: row[9].to_i unless product.is_fixed_price?
  #        stock_items_attributes = {}
  #        shops.each_with_index do |shop, s|
  #          if (stock_item = StockItem.where(product_id: product.id, shop_id: shop.id)).present?
  #            attributes = { id: stock_item.first.id, quantity: row[shop_cols[s]].to_i }
  #          else
  #            attributes = { quantity: row[shop_cols[s]].to_i, product_id: product.id, shop_id: shop.id }
  #          end
  #          stock_items_attributes.merge! s.to_s => attributes
  #        end
  #        new_attributes.merge! stock_items_attributes: stock_items_attributes
  #        product.attributes = new_attributes
  #        products << product
  #        import_log << ['success', 'New attributes: ' + new_attributes.inspect]
  #      else
  #        import_log << ['important', "Product with code [#{code_1c}] not found!"]
  #      end
  #    end
  #  end
  #  import_log << ['inverse', '-'*160]
  #  products
  #end

  private

  def open_spreadsheet
    filename = rename_uploaded_file file
    case File.extname(file.original_filename)
      when ".xls" then Roo::Excel.new(filename, nil, :ignore)
      when ".xlsx" then Roo::Excelx.new(file.path, nil, :ignore)
      else raise "Unknown file type: #{file.original_filename}"
    end
  end

  def rename_uploaded_file(file)
    begin
      new_file = File.join File.dirname(file.path), file.original_filename
      File.rename file.path, new_file
    rescue SystemCallError => error
      return error.to_s
    end
    return new_file
  end

end