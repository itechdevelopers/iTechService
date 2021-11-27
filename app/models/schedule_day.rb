class ScheduleDay < ApplicationRecord
  belongs_to :user

  delegate :department, :department_id, to: :user

  # attr_accessible :day, :hours, :user, :user_id

  default_scope {order('day asc')}

  def hours_array
    hours.present? ? hours.split(',') : []
  end

  def begin_of_work(date=nil)
    date ||= Time.current
    if hours_array.any?
      date.change hour: hours_array.first.to_i, min: 0, sec: 0
    else
      nil
    end
  end

  def end_of_work(date=nil)
    date ||= Time.current
    if hours_array.any?
      date.change hour: hours_array.last.to_i, min: 59, sec: 59
    else
      nil
    end
  end

end
