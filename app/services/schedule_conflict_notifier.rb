# frozen_string_literal: true

# Detects and notifies about schedule conflicts:
# 1. When a user is fired but has future duty/cashier assignments
# 2. When a user gets sick leave/vacation but is assigned to duty/cashier on that date
class ScheduleConflictNotifier
  def self.on_dismissal(user)
    cutoff = user.dismissed_date&.to_date || Date.current
    conflicts = []

    # Schedule conflicts (working days in ScheduleEntry)
    working_entries = ScheduleEntry.where(user_id: user.id)
                                   .where('date >= ?', cutoff)
                                   .includes(:department, :shift, :occupation_type)
                                   .select { |e| e.occupation_type&.counts_as_working? }
    working_entries.each do |entry|
      shift_info = entry.custom_shift? ? "#{entry.custom_start_time.strftime('%H:%M')}-#{entry.custom_end_time.strftime('%H:%M')}" : entry.shift&.name
      conflicts << I18n.t('schedule_conflict_notifications.schedule_dismissed',
                          name: user.short_name,
                          date: I18n.l(entry.date, format: '%d.%m.%Y'),
                          department: entry.department&.name,
                          shift: shift_info,
                          dismissed_date: cutoff.strftime('%d.%m.%Y'))
    end

    # Duty conflicts
    DutyScheduleEntry.where(user_id: user.id).where('date >= ?', cutoff).find_each do |entry|
      conflicts << I18n.t('schedule_conflict_notifications.duty_dismissed',
                          name: user.short_name,
                          duty_date: I18n.l(entry.date, format: '%d.%m.%Y'),
                          dismissed_date: cutoff.strftime('%d.%m.%Y'))
    end

    # Cashier conflicts
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

    send_to_telegram(message)
  end

  def self.send_to_telegram(message)
    chat_id = ENV['TELEGRAM_SCHEDULE_CONFLICT_CHAT_ID']
    return unless chat_id.present?

    text = "<b>⚠️ Конфликт в графике</b>\n\n#{message}"
    SendTelegramMessage.call(chat_id: chat_id, text: text)
  end

  private_class_method :notify_superadmins
end
