class GlassStickingRecipientsQuery
  MODES = %w[bar_working_now bar_all all_department].freeze
  DEFAULT_MODE = 'bar_working_now'.freeze

  def initialize(department:, mode: DEFAULT_MODE, name: nil)
    @department = department
    @mode = MODES.include?(mode) ? mode : DEFAULT_MODE
    @name = name.to_s.strip
  end

  def call
    scope = base_scope
    scope = filter_by_name(scope) if @name.present?
    scope.order('users.surname ASC, users.name ASC')
  end

  attr_reader :mode

  private

  def base_scope
    case @mode
    when 'bar_working_now'
      User.active.where(id: working_now_user_ids).joins(:location).where(locations: { code: 'bar' })
    when 'bar_all'
      User.active.where(department: @department).joins(:location).where(locations: { code: 'bar' })
    when 'all_department'
      User.active.where(department: @department)
    end
  end

  def working_now_user_ids
    ScheduleEntry.working_now_in(@department, at: now_in_city).map(&:user_id).uniq
  end

  def now_in_city
    tz = @department.city&.time_zone || 'Vladivostok'
    Time.current.in_time_zone(tz)
  end

  def filter_by_name(scope)
    q = "%#{@name}%"
    scope.where(
      'users.username ILIKE :q COLLATE "ru_RU.utf8" OR ' \
      'users.name ILIKE :q COLLATE "ru_RU.utf8" OR ' \
      'users.surname ILIKE :q COLLATE "ru_RU.utf8"',
      q: q
    )
  end
end
