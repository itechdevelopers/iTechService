# frozen_string_literal: true

module SchedulesHelper
  DAY_NAMES_SHORT = %w[Пн Вт Ср Чт Пт Сб Вс].freeze

  def format_working_hours_summary(department)
    hours = department.working_hours.ordered.to_a
    return t('schedules.index.working_hours_not_set') if hours.empty?

    groups = group_consecutive_days(hours)
    groups.map { |group| format_group(group) }.join(', ')
  end

  private

  def group_consecutive_days(hours)
    groups = []
    current_group = []

    hours.each do |wh|
      if current_group.empty? || same_schedule?(current_group.last, wh)
        current_group << wh
      else
        groups << current_group
        current_group = [wh]
      end
    end
    groups << current_group unless current_group.empty?
    groups
  end

  def same_schedule?(wh1, wh2)
    wh1.is_closed == wh2.is_closed &&
      wh1.opens_at == wh2.opens_at &&
      wh1.closes_at == wh2.closes_at
  end

  def format_group(group)
    first_day = group.first
    last_day = group.last

    day_range = if group.size == 1
                  DAY_NAMES_SHORT[first_day.day_of_week]
                else
                  "#{DAY_NAMES_SHORT[first_day.day_of_week]}-#{DAY_NAMES_SHORT[last_day.day_of_week]}"
                end

    if first_day.is_closed?
      "#{day_range} #{t('schedules.index.closed')}"
    else
      "#{day_range} #{first_day.opens_at&.strftime('%H:%M')}-#{first_day.closes_at&.strftime('%H:%M')}"
    end
  end

  # Format audit details for schedule entry changes
  # Handles create/update/destroy actions and resolves IDs to names
  def format_audit_details(audit)
    changes = audit.audited_changes
    skip_attrs = %w[id created_at updated_at schedule_group_id user_id date]
    relevant_attrs = %w[department_id shift_id occupation_type_id]

    details = []

    case audit.action
    when 'create'
      relevant_attrs.each do |attr|
        next unless changes.key?(attr)

        value = changes[attr]
        next unless value

        name = resolve_audit_value(attr, value)
        details << "#{audit_attr_label(attr)}: #{name}"
      end
    when 'update'
      changes.each do |attr, values|
        next if skip_attrs.include?(attr)
        next unless relevant_attrs.include?(attr)

        old_val, new_val = values
        old_name = resolve_audit_value(attr, old_val)
        new_name = resolve_audit_value(attr, new_val)
        details << "#{audit_attr_label(attr)}: #{old_name} → #{new_name}"
      end
    when 'destroy'
      relevant_attrs.each do |attr|
        next unless changes.key?(attr)

        value = changes[attr]
        next unless value

        name = resolve_audit_value(attr, value)
        details << "#{audit_attr_label(attr)}: #{name}"
      end
    end

    details
  end

  def audit_attr_label(attr)
    I18n.t("schedule_groups.history_modal_form_content.attr_#{attr}", default: attr.humanize)
  end

  def resolve_audit_value(attr, value)
    return '-' if value.nil?

    case attr
    when 'department_id'
      Department.find_by(id: value)&.schedule_config&.short_name ||
        Department.find_by(id: value)&.name ||
        value.to_s
    when 'shift_id'
      Shift.find_by(id: value)&.short_name ||
        Shift.find_by(id: value)&.name ||
        value.to_s
    when 'occupation_type_id'
      OccupationType.find_by(id: value)&.name || value.to_s
    else
      value.to_s
    end
  end
end
