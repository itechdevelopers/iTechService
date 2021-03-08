class ProductPrice < ActiveRecord::Base
  default_scope { order('date desc') }
  scope :newest_first, -> { order('date desc') }
  scope :with_type, ->(type) { where(price_type_id: type) }
  scope :for_datetime, ->(datetime) { where(date: datetime) }
  scope :for_date, ->(date) { where(date: date.beginning_of_day..date) }
  scope :purchase, -> { where(price_type_id: PriceType.purchase.id) }
  scope :retail, -> { where(price_type_id: PriceType.retail.id) }

  belongs_to :department
  belongs_to :product
  belongs_to :price_type

  # attr_accessible :value, :date, :product_id, :price_type_id, :department_id

  validates_presence_of :product, :price_type, :date, :value

  delegate :kind, :kind_s, :is_purchase?, :is_retail?, to: :price_type, allow_nil: true

  after_initialize do
    self.date ||= DateTime.current
    self.department_id ||= Department.current.id
  end

  def self.find_for_time_or_date(date)
    for_datetime(date).first || for_date(date).first
  end

  def find_previous
    ProductPrice.where(price_type_id: price_type_id, product_id: product_id).
      where('date < ?', date).first
  end
end
