class SaleItem < ApplicationRecord

  belongs_to :sale, inverse_of: :sale_items, optional: true
  belongs_to :item, inverse_of: :sale_items, optional: true
  belongs_to :device_task, inverse_of: :sale_item, optional: true
  # has_many :batches, through: :item, conditions: proc {  }
  delegate :product, :product_category, :features, :name, :code, :quantity_in_store, :retail_price,
           :feature_accounting, :store_item, :store_items, :is_service, :is_service?, :is_repair?,
           :request_price, :warranty_term, :features_s, to: :item, allow_nil: true
  delegate :store, :client, :date, :is_return, to: :sale, allow_nil: true
  delegate :id, to: :product, prefix: true, allow_nil: true

  # attr_accessible :sale_id, :item_id, :price, :quantity, :discount, :device_task_id
  validates_presence_of :item, :price, :quantity
  validates_numericality_of :quantity, only_integer: true, greater_than: 0, unless: :feature_accounting
  validates_numericality_of :quantity, only_integer: true, equal_to: 1, if: :feature_accounting
  validates_numericality_of :discount, greater_than_or_equal_to: 0, less_than_or_equal_to: :max_discount, message: I18n.t('sales.errors.unavailable_discount'), allow_nil: true, unless: Proc.new { |a| a.discount.nil? }
  validates_numericality_of :price, greater_than_or_equal_to: :min_price, unless: Proc.new { |a| a.min_price.nil? }

  after_initialize do
    self.quantity ||= 1
    self.price ||= retail_price if retail_price.present?
    self.discount ||= available_discount
  end

  def sum
    (price || 0) * (quantity || 0)
  end

  def available_discount
    item.present? ? Discount.available_for(client, item) : nil
  end

  def discount=(new_discount)
    if is_return or is_repair?
      super
    else
      if retail_price.present? && retail_price > 0
        if User.current.try :any_admin?
          self.price = retail_price - new_discount.to_f
          super
        else
          if new_discount.to_f > available_discount
            self.errors.add :discount, I18n.t('sales.errors.unavailable_discount')
          else
            self.price = retail_price - new_discount.to_f
            super
          end
        end
      else
        self.errors.add :discount, I18n.t('activerecord.errors.models.product.no_retail_price')
      end
    end
  end

  def max_discount
    if User.current.try :any_admin?
      retail_price || price
    else
      item.present? ? Discount.max_available_for(client, item) || price : 0
    end
  end

  def min_price
    if User.current.try :any_admin?
      0
    else
      retail_price.present? ? retail_price - max_discount : 0
    end
  end

  def batch
    item.batches.includes(:purchase).where('purchases.date <= ?', created_at).order('purchases.date asc').last || item.batches.where('created_at <= ?', created_at).order('created_at asc').last
  end

  def purchase_price
    if is_repair?
      device_task.try(:repair_cost)
    else
      batch.try(:price) || product.prices.purchase.where('product_prices.date <= ?', created_at).order('created_at asc').last.try(:value)
    end
  end

  def margin
    price - (purchase_price || 0)
  end

end