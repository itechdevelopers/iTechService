class DeviceTask < ActiveRecord::Base
  scope :in_department, ->(department) { where(service_job_id: ServiceJob.in_department(department)) }
  scope :ordered, ->{joins(:task).order('done asc, tasks.priority desc')}
  scope :pending, ->{where(done: 0)}
  scope :done, ->{where(done: 1)}
  scope :undone, ->{where(done: 2)}
  scope :processed, ->{where(done: [1,2])}
  scope :tasks_for, ->(user) { joins(:service_job, :task).where(service_jobs: {location_id: user.location_id}, tasks: {role: user.role}) }
  scope :paid, ->{where('device_tasks.cost > 0')}

  belongs_to :service_job
  belongs_to :task
  belongs_to :performer, class_name: 'User'
  has_many :history_records, as: :object
  has_many :repair_tasks, inverse_of: :device_task
  has_many :repair_parts, through: :repair_tasks
  has_one :sale_item, inverse_of: :device_task

  delegate :name, :role, :code, :is_important?, :is_repair?, :item, :mac_service?, to: :task, allow_nil: true
  delegate :cost, to: :task, prefix: true, allow_nil: true
  delegate :client_presentation, :ticket_number, to: :service_job, allow_nil: true
  delegate :department, :department_id, :user, to: :service_job

  attr_accessible :done, :done_at, :comment, :user_comment, :cost, :task, :service_job, :service_job_id, :task_id, :performer_id, :performer, :task, :service_job_attributes, :repair_tasks_attributes

  accepts_nested_attributes_for :service_job, reject_if: proc { |attr| attr['tech_notice'].blank? }
  accepts_nested_attributes_for :repair_tasks, allow_destroy: true

  validates :task, :cost, presence: true
  validates :cost, numericality: true
  validate :valid_repair if :is_repair?
  validates_associated :repair_tasks
  after_commit :update_service_job_done_attribute
  # after_save :deduct_spare_parts if :is_repair?
  after_initialize :set_performer

  before_save do |dt|
    old_done = dt.done_was
    if dt.done != 0 and old_done == 0
      dt.done_at = DateTime.current
      dt.performer_id ||= User.current&.id
    elsif dt.done != 1 and old_done == 1
      dt.done_at = nil
    end
  end

  def as_json(options={})
    {
      id: id,
      name: name,
      done: done,
      cost: cost,
      comment: comment,
      user_comment: user_comment
    }
  end

  def task_name
    task.try :name
  end

  def task_cost
    task.try(:cost) || 0
  end
  
  def task_duration
    task.try :duration
  end

  def service_job_presentation
    service_job.present? ? service_job.presentation : ''
  end

  def performer_name
    performer.present? ? performer.short_name : ''
  end

  def repair_cost
    repair_tasks.sum(:price)
  end

  def done_s
    %w(pending done undone)[done]
  end

  def pending?
    done == 0
  end

  def done?
    done == 1
  end

  def undone?
    done == 2
  end

  private

  def update_service_job_done_attribute
    return if service_job.nil?

    done_time = self.service_job.done? ? self.service_job.device_tasks.maximum(:done_at).getlocal : nil
    self.service_job.update_attribute :done_at, done_time
  end

  # def deduct_spare_parts
  #   if done_change == [0, 1]
  #     repair_tasks.each do |repair_task|
  #       repair_task.repair_parts.all? do |repair_part|
  #         repair_part.deduct_spare_parts
  #       end
  #     end
  #   end
  # end

  def valid_repair
    is_valid = true
    if done_change == [0, 1]
      if done_was > 0
        errors.add :done, :already_done
        is_valid = false
      # else
      #   repair_tasks.each do |repair_task|
      #     repair_task.repair_parts.each do |repair_part|
      #       if repair_part.store.present?
      #         if repair_part.store_item(repair_part.store).quantity < (repair_part.quantity + repair_part.defect_qty)
      #           errors[:base] << I18n.t('device_tasks.errors.insufficient_spare_parts', name: repair_part.name)
      #           is_valid = false
      #         end
      #       else
      #         errors.add :base, :no_spare_parts_store
      #         is_valid = false
      #       end
      #     end
      #     if repair_task.repair_parts.sum(:defect_qty) > 0 and (Department.current.defect_sp_store.nil?)
      #       errors.add :base, :no_defect_store
      #       is_valid = false
      #     end
      #   end
      end
    end
    is_valid
  end

  def set_performer
    if performer_id.nil? and done and (user = history_records.task_completions.order_by_newest.where(new_value: true).first.try(:user)).present?
      update_attribute :performer_id, user.id
    end
  end
end
