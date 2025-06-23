class ResumeDepartmentUsersService
  def self.call(department_id)
    new(department_id).call
  end

  def initialize(department_id)
    @department_id = department_id
  end

  def call
    paused_users = User.in_department(@department_id).where(paused: true)
    paused_users.each(&:resume!)
    
    paused_users.count
  end

  private

  attr_reader :department_id
end 