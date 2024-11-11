module UsersHelper
  def user_row_tag(user)
    content_tag(:tr, id: "user_row_#{user.id}", class: user.is_fired? ? 'user_row error' : 'user_row') do
      c = ''.html_safe
      c += content_tag(:td, link_to(user.id, user_path(user)))
      c += content_tag(:td, link_to(user.username, user_path(user), class: "highlight", data: { color: user.city.color }))
      c += content_tag(:td) do
        c = link_to(user_path(user)) do
          c = ''.html_safe
          c += image_tag user.photo.medium.url, class: :avatar if user.photo?
          c + user.short_name
        end
        "#{c} #{senior_label_tag(user)}".html_safe
      end
      c += user_achievements_tag(user)
      c += content_tag(:td, t("users.roles.#{user.role}"))
      c += content_tag(:td, link_to(user.location_short_name || '-', user_path(user), class: "highlight", data: { color: user.city.color }))
      c += content_tag(:td) do
        content_tag(:div, class: 'btn-group') do
          content = link_to_show_small(user)
          content += link_to glyph(:'minus-circle'), new_user_fault_path(user), remote: true, class: 'btn btn-small'
          content += link_to glyph(:money), finance_user_path(user), remote: true, class: 'btn btn-small'
          content += link_to_edit_small(user) if can? :edit, user
          content
        end
      end
      c
    end.html_safe
  end

  def user_achievements_tag(user)
    achievements = user.user_achievements.includes(:achievement).to_a
    total_count = achievements.size

    content_tag(:td, class: 'achievements-cell') do
      icons = achievements.first(4).map do |user_achievement|
        achievement = user_achievement.achievement
        link_to user_path(user, anchor: 'achievements_tab') do
          image_tag(achievement.icon_mini.url,
                    class: 'achievement-img-icon-mini has-tooltip',
                    data: { original_title: achievement.name })
        end
      end

      if total_count > 4
        icons << content_tag(:div, class: 'full-achievements-btn') do
          content_tag(:b, '', class: 'caret')
        end
        icons << content_tag(:div, class: 'full-achievements hidden') do
          all_icons = achievements.map do |user_achievement|
            achievement = user_achievement.achievement
            link_to user_path(user, anchor: 'achievements_tab') do
              image_tag(achievement.icon_mini.url,
                        class: 'achievement-img-icon-mini has-tooltip',
                        data: { original_title: achievement.name })
            end
          end
          safe_join(all_icons)
        end
      end
      safe_join(icons)
    end
  end

  def senior_label_tag(user)
    label = ""
    label << " #{image_tag("certificate.png", title: t("users.senior"), class: 'user-senior has-tooltip')}" if user.is_senior?
    label
  end

  def schedule_hour_class_for(user, day, hour)
    schedule_hour_class = ''
    if (schedule_day = user.schedule_days.find_by_day day).present? && !schedule_day.hours.blank?
      hours = schedule_day.hours.split ','
      schedule_hour_class = 'work_hour' if hours.include? hour.to_s
    end
    schedule_hour_class
  end

  def hour_attributes_for(user, day, hour)
    color = 'inherit'
    hour_class = 'job_schedule_user_hour'
    user_id = ''
    if user.present? && (schedule_day = user.schedule_days.find_by_day day).present?
      user_id = user.id
      unless schedule_day.hours.blank?
        hours = schedule_day.hours.split ','
        if hours.include? hour.to_s
          color = user.color_s
          hour_class << ' work_hour'
        end
      end
    end
    { style: "background-color: #{color}", class: hour_class, data: { hour: hour }, title: user.short_name }
  end

  def hours_attributes_for(user, day, day_id = nil)
    color = user.try(:color_s) || 'inherit'
    user_id = user.try(:id) || ''
    day_id ||= user.present? ? user.schedule_days.find_by_day(day).try(:id) : ''
    { class: 'job_schedule_user_hours', data: { user: user_id, day: day, dayid: day_id, color: color } }
  end

  def user_hours_row_tag(day, user = nil, day_id = nil)
    content_tag(:tr, hours_attributes_for(user, day, day_id)) do
      (10..20).collect do |hour|
        tag(:td, hour_attributes_for(user, day, hour))
      end.join.html_safe +
        content_tag(:td, class: 'job_schedule_hours_actions') do
          link_to(icon_tag('ok-sign'), '#', remote: true, class: 'save_job_schedule_hours pull-left') +
            link_to(icon_tag('times-circle'), '#', remote: true, class: 'delete_job_schedule_hours pull-right')
        end.html_safe
    end.html_safe
  end

  def link_to_add_user_hours(day)
    link_to icon_tag('plus-sign'), '#', remote: true, class: 'add_user_to_job_schedule', data: { day: day }
  end

  def duty_calendar(kind, month, user = nil)
    days = calendar_month_days(month).in_groups_of(7)
    table_caption = t("duty_days.title.#{kind}")
    container_class = 'calendar'
    if user.nil?
      container_id = 'staff_duty_schedule'
      container_class << ' editable staff_calendar'
      prev_link = link_to('&larr;'.html_safe, staff_duty_schedule_users_path(date: month.prev_month, kind: kind),
                          remote: true)
      # prev_link = link_to(glyph('long-arrow-left'), staff_duty_schedule_users_path(date: month.prev_month, kind: kind), remote: true)
      next_link = link_to('&rarr;'.html_safe, staff_duty_schedule_users_path(date: month.next_month, kind: kind),
                          remote: true)
      # next_link = link_to(glyph('long-arrow-right'), staff_duty_schedule_users_path(date: month.next_month, kind: kind), remote: true)
    else
      container_id = 'calendar'
      container_class << (action_name == 'edit' ? ' user_calendar editable' : ' user_calendar')
      prev_link = link_to('&larr;'.html_safe, duty_calendar_user_path(user, date: month.prev_month, kind: kind),
                          remote: true)
      # prev_link = link_to(glyph('long-arrow-left'), duty_calendar_user_path(user, date: month.prev_month, kind: kind), remote: true)
      next_link = link_to('&rarr;'.html_safe, duty_calendar_user_path(user, date: month.next_month, kind: kind),
                          remote: true)
      # next_link = link_to(glyph('long-arrow-right'), duty_calendar_user_path(user, date: month.next_month, kind: kind), remote: true)
    end
    container_id << "_#{kind}"

    content_tag(:div, id: container_id, class: container_class, data: { kind: kind }) do
      content_tag(:table, class: 'table table-bordered table-condensed') do
        content_tag(:caption) do
          content_tag(:h4, table_caption)
        end <<
          content_tag(:thead) do
            content_tag(:tr) do
              content_tag(:th, colspan: 8) do
                content_tag(:ul, class: 'pager') do
                  content_tag(:li, prev_link, class: 'previous') <<
                    content_tag(:li,
                                content_tag(:span, "#{t('date.month_names_single')[month.month]} #{month.year}")) <<
                    content_tag(:li, next_link, class: 'next')
                end
              end
            end <<
              content_tag(:tr) do
                tag(:th) <<
                  t('date.abbr_day_names').map do |day|
                    content_tag(:th, content_tag(:strong, day))
                  end.join.html_safe
              end
          end <<
          content_tag(:tbody) do
            rows_tag = ''
            days.each_index do |w|
              rows_tag << content_tag(:tr) do
                content_tag(:td, content_tag(:strong, w + 1)) <<
                  days[w].map do |day|
                    duty_day_cell(kind, day, month.month, user)
                  end.join.html_safe
              end
            end
            rows_tag.html_safe
          end << if user.nil?
                   ''
                 else
                   content_tag(:tfoot) do
                     next_duties(Date.current, kind).map do |duty_day|
                       content_tag(:tr) do
                         content_tag(:td, duty_day.day.strftime('%d.%m.%y'),
                                     colspan: 2) <<
                           content_tag(:td, (duty_day.user.full_name.blank? ? duty_day.user.username : duty_day.user.full_name),
                                       colspan: 6)
                       end
                     end.join.html_safe
                   end
                 end
      end
    end
  end

  def duty_day_cell(kind, day, month, user = nil)
    content_tag(:td, duty_day_attributes(kind, day, month, user)) do
      if day.today?
        content_tag :span, day.day, class: 'badge badge-info'
      else
        content_tag :span, day.day, class: 'badge badge-blank'
      end
    end.html_safe
  end

  def duty_day_attributes(kind, day, month, user = nil)
    if user.nil?
      day_class = ''
      day_class = 'today' if day.today?
      day_class << (day.month == month ? ' calendar_day' : ' muted')
      day_color = 'inherit'
      day_id = ''
      style = ''
      duty_day = DutyDay.get_for(current_city, kind, day)
      duty_user = duty_day&.user

      if duty_day.present? && duty_user.present?
        day_id = duty_day.id
        day_color = duty_user.color
        day_class << ' duty'
        style = "background-color: #{day_color}" if day_class.include? 'calendar_day'
      else
        day_class << ' empty'
      end
      { class: day_class, data: { user: duty_user&.id || '', dayid: day_id, day: day.to_s, color: day_color },
        style: style, title: duty_user&.short_name }
    else
      { class: calendar_day_class(user, day, month) }
    end
  end

  def calendar_day_class(user, day, month)
    day_class = ''
    day_class << 'today' if day.today?
    day_class << ' work_day' if user.is_work_day? day
    day_class << ' shortened' if user.is_shortened_day? day
    day_class << ' duty' if user.is_duty_day? day
    if is_other_duty? user, day
      day_class << ' other_duty'
    elsif can? :manage, user
      day_class << ' empty'
    end
    day_class << (day.month == month ? ' calendar_day' : ' muted')
  end

  def calendar_month_days(date)
    start_day = date.beginning_of_month.beginning_of_week
    end_day = date.end_of_month.end_of_week
    (start_day..end_day).to_a
  end

  def next_other_duties(user, date)
    DutyDay.where('user_id <> ? AND day > ?', user.id, date).reorder('day asc')
  end

  def next_duties(date, kind)
    DutyDay.where('day >= ? AND kind = ?', date, kind).reorder('day asc')
  end

  def profile_link
    link_to current_user.short_name,
            profile_path,
            id: 'profile_link',
            data: {
              id: current_user.id,
              helpable: current_user.helpable?,
              location: current_user.location_id,
              role: current_user.role,
              timeout_in: current_user.timeout_in
            }
  end

  def karma_tag(user)
    badge_class = 'badge'
    good_count = user.karmas.good.count
    bad_count = user.karmas.bad.count
    if good_count.positive? || bad_count.positive?
      diff = good_count - bad_count
      badge_class << ' badge-success' if diff > 1
      badge_class << ' badge-important' if diff < -1
      badge_class << ' badge-warning' if diff.between?(-1, 1)
    end
    content_tag :span, "#{good_count} / #{bad_count}", class: badge_class
  end

  def duty_info_tag
    kind = current_user.current_duty_day&.kind
    return if kind.nil?

    content_tag :div, id: 'duty_info', class: 'alert alert-block' do
      content_tag :h4, t("users.duty_info.#{kind}")
    end
  end

  def accessible_roles
    current_user.superadmin? || current_user.developer? ? User::ROLES : User::ROLES_FOR_ADMIN
  end

  def dismissal_reasons
    DismissalReason.all
  end

  private

  def is_other_duty?(user, date)
    DutyDay.duties_except_user(user).exists?(day: date)
  end
end
