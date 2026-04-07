# frozen_string_literal: true

# Detects and notifies about schedule conflicts:
# 1. When a user is fired but has future duty/cashier assignments
# 2. When a user gets sick leave/vacation but is assigned to duty/cashier on that date
class ScheduleConflictNotifier
  def self.on_dismissal(user)
    cutoff = user.dismissed_date&.to_date || Date.current
    conflicts = []

    DutyScheduleEntry.where(user_id: user.id).where('date >= ?', cutoff).find_each do |entry|
      conflicts << I18n.t('schedule_conflict_notifications.duty_dismissed',
                          name: user.short_name,
                          duty_date: I18n.l(entry.date, format: '%d.%m.%Y'),
                          dismissed_date: cutoff.strftime('%d.%m.%Y'))
    end

    CashierScheduleEntry.where(user_id: user.id).where('date >= ?', cutoff).find_each do |entry|
      conflicts << I18n.t('schedule_conflict_notifications.cashier_dismissed',
                          name: user.short_name,
                          duty_date: I18n.l(entry.date, format: '%d.%m.%Y'),
                          dismissed_date: cutoff.strftime('%d.%m.%Y'))
    end

    notify_superadmins(conflicts) if conflicts.any?
  end

  def self.on_non_working_schedule(user, date)
    conflicts = []

    if DutyScheduleEntry.where(user_id: user.id, date: date).exists?
      conflicts << I18n.t('schedule_conflict_notifications.duty_non_working',
                          name: user.short_name,
                          date: I18n.l(date, format: '%d.%m.%Y'))
    end

    if CashierScheduleEntry.where(user_id: user.id, date: date).exists?
      conflicts << I18n.t('schedule_conflict_notifications.cashier_non_working',
                          name: user.short_name,
                          date: I18n.l(date, format: '%d.%m.%Y'))
    end

    notify_superadmins(conflicts) if conflicts.any?
  end

  def self.notify_superadmins(messages)
    superadmins = User.where(role: 'superadmin').active
    message = messages.join("\n")

    superadmins.find_each do |admin|
      Notification.create!(
        user: admin,
        message: message
      )
    end
  end

  private_class_method :notify_superadmins
end
