class HistoryRecord < ActiveRecord::Base

  belongs_to :user
  belongs_to :object, polymorphic: true
  # attr_accessible :column_name, :column_type, :deleted_at, :new_value, :old_value, :user, :object

  scope :order_by_newest, -> { order('created_at desc') }
  scope :service_jobs, -> { where(object_type: 'ServiceJob') }
  scope :device_tasks, -> { where(object_type: 'DeviceTask') }
  scope :task_completions, -> { where(object_type: 'DeviceTask', column_name: 'done') }
  scope :movements, -> { service_jobs.where(column_name: 'location_id') }
  scope :movements_from, ->(location) do
    location = location.pluck(:id) if location.respond_to?(:pluck)
    location = location.id if location.respond_to?(:id)
    movements.where(old_value: location)
  end
  scope :movements_to, ->(location) do
    location = location.pluck(:id) if location.respond_to?(:pluck)
    location = location.id if location.respond_to?(:id)
    movements.where(new_value: location)
  end

  scope :movements_from_to, ->(from_location, to_location) do
    from_location = from_location.pluck(:id) if from_location.respond_to?(:pluck)
    from_location = from_location.id if from_location.respond_to?(:id)
    to_location = to_location.pluck(:id) if to_location.respond_to?(:pluck)
    to_location = to_location.id if to_location.respond_to?(:id)
    movements.where(old_value: from_location, new_value: to_location)
  end

  scope :movements_to_archive, ->(department = nil) do
    archive_ids = department ? Location.in_department(department).archive_ids : Location.archive_ids
    service_jobs.where(column_name: 'location_id', new_value: archive_ids)
  end

  scope :in_period, ->(period) { where(created_at: period) }
  scope :by_user, ->(user) { where(user_id: (user.is_a?(User) ? user.id : user.to_i)) }
  scope :service_jobs_movements, -> { service_jobs.movements }

  def user_name
    user.present? ? user.short_name : ''
  end

end
