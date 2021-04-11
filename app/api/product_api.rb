class ProductApi < Grape::API
  version 'v1', using: :path
  before { authenticate! }

  helpers do
    def products_hash(products)
      res = {}
      products.each do |product|
        res.store product.code.to_s, { price: product.retail_price, remnants: product.remnants_hash }
      end
      res
    end
  end

  desc 'Get products remnants for shops'
  post 'products_sync' do
    authorize :sync, Product
    products_hash Product.goods
  end

  desc 'Get products remnants'
  get 'remnants' do
    authorize :read, Product
    if (store = current_user.default_store).present?
      if params[:group_id].present?
        product_group = ProductGroup.find params[:group_id]
        product_groups = product_group.children
        products = product_group.products
        present :remnants, products, with: Entities::ProductEntity, store: store
      elsif params[:product_q].present?
        products = Product.search params
        product_groups = ProductGroup.where id: products.collect(&:product_group_id)
        present :remnants, products, with: Entities::ProductEntity, store: store, show_group: true
      else
        product_groups = ProductGroup.search(roots: true, user_role: current_user.role)
      end
      present :groups, product_groups, with: Entities::ProductGroupEntity
    else
      error!({error: 'Retail store undefined'}, 404)
    end
  end

end