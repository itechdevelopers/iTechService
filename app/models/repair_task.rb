class RepairTask < ApplicationRecord
  scope :in_department, ->(department) { where(device_task_id: DeviceTask.in_department(department)) }

  belongs_to :repair_service
  belongs_to :device_task
  belongs_to :store
  belongs_to :repairer, class_name: 'User'
  has_many :repair_parts, inverse_of: :repair_task

  delegate :name, :repair_group, :is_positive_price, to: :repair_service, allow_nil: true
  delegate :price, to: :repair_service, prefix: true, allow_nil: true
  delegate :user, :service_job, :performer, :done, :done?, :pending?, :undone?, :department, to: :device_task, allow_nil: true

  accepts_nested_attributes_for :repair_parts

  validates :price, :repair_service, :store, presence: true
  validates :price, numericality: true
  validates_numericality_of :price, greater_than: 0, if: :is_positive_price
  # validates_numericality_of :price, greater_than_or_equal_to: :repair_service_price, if: :is_positive_price
  validates :repair_service_id, uniqueness: {scope: [:device_task_id]}
  validates_associated :repair_parts
  before_destroy :return_spare_parts

  after_initialize do
    self.price ||= repair_service&.price(department)
    self.store_id = Department.current.spare_parts_store.id
    # self.store_id = User.current.try(:spare_parts_store).try(:id)
    if repair_service.present? and repair_parts.empty?
      repair_service.spare_parts.each do |spare_part|
        repair_parts.build(item_id: spare_part.product.items&.first&.id, quantity: spare_part.quantity)
      end
    end
  end

  def margin
    price - parts_cost
  end

  def parts_cost
    repair_parts.to_a.sum(&:purchase_price)
  end

  def self.return_defected_parts(item_ids)
    items = Item.where id: item_ids
    if (defect_sp_store = Department.current.defect_sp_store).present?
      items.each do |item|
        item.store_item(defect_sp_store).add 1
      end
    end
  end

  private

  def return_spare_parts
    repair_parts.all? do |repair_part|
      repair_part.unstash
    end
  end
end
