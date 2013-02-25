class DeviceTask < ActiveRecord::Base
  belongs_to :device
  belongs_to :task
  has_many :history_records, as: :object
  attr_accessible :done, :comment, :user_comment, :cost, :task, :device, :device_id, :task_id
  validates :task_id, :cost, presence: true
  validates :cost, numericality: true # except repair
  
  scope :ordered, joins(:task).order("done asc, tasks.priority desc")
  scope :done, where(done: true)
  scope :pending, where(done: false)
  scope :tasks_for, lambda { |user| joins(:device, :task).where(devices: {location_id: user.location_id},
                                                                tasks: {role: user.role}) }
  
  #after_initialize {|dt| dt.cost ||= task_cost; dt.done ||= false}

  before_save do |dt|
    dt.done = false if dt.done.nil?
    old_done = changed_attributes['done']
    if dt.done and (!old_done or old_done.nil?)
      dt.done_at = Time.now
    elsif !dt.done and old_done
      dt.done_at = nil
    end
  end
  
  after_commit do |dt|
    done_time = dt.device.done? ? dt.device.device_tasks.maximum(:done_at).getlocal : nil
    dt.device.update_attribute :done_at, done_time
  end
  
  def task_name
    task.try :name
  end

  def name
    task.try :name
  end

  def task_cost
    task.try(:cost) || 0
  end
  
  def task_duration
    task.try :duration
  end
  
  def is_important?
    task.try :is_important?
  end

  def device_presentation
    device.presentation
  end

  def client_presentation
    device.client_presentation
  end

  def role
    task.role
  end

  def is_actual_for? user
    task.is_actual_for? user
  end

end