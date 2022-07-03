module TopBarHelper
  def header_link_to_feedbacks
    link_to glyph('phone'), '#', id: 'feedback_notifications-link', rel: 'popover',
            data: {html: true, placement: 'bottom', content: ''}
  end

  def header_links_to_stale_jobs
    1.upto(2).map { |i|
      link_to(glyph('inbox'), '#', id: "stale_jobs-link-#{i}", class: 'notification', rel: 'popover',
              data: {html: true, placement: 'bottom', content: ''})
    }.join(' ').html_safe
  end

  def link_to_trade_in_purgatory
    if can?(:manage, TradeInDevice) && TradeInDevice.unconfirmed.any?
      link_to(t('trade_in_device.purgatory'), purgatory_trade_in_devices_path)
    end
  end

  def staff_experience_list(users)
    today = Date.current
    content_tag(:table, id: 'staff_experience_list', class: 'table table-condensed table-hover') do
      users.map do |user|
        content_tag(:tr) do
          time_text = if user.upcoming_salary_date&.today?
                        text = 'Отработал(а)'
                        years, months = ((Time.current - user.hiring_date.to_time) / 1.month).divmod(12)

                        if years > 0
                          text << " #{years}"
                          text << if years == 1 || (years > 20 && years.modulo(10) == 1)
                                    ' год'
                                  elsif (years < 5 || years > 20) && years.modulo(10).in?(2..4)
                                    ' года'
                                  else
                                    ' лет'
                                  end
                        end

                        months = months.to_i
                        if months > 0
                          text << " #{months} мес."
                        end

                        text
                      else
                        "#{t(:in_time)} #{distance_of_time_in_words(today, user.upcoming_salary_date)}"
                      end
          content_tag(:td, link_to(user.short_name, user_path(user))) +
            content_tag(:td, time_text)
        end
      end.join.html_safe
    end.html_safe
  end

  def header_link_to_staff_experience
    # users = User.oncoming_salary
    # notify_class = users.any? ? 'notify' : ''
    link_to image_tag('exp-icon.png'), '#', rel: 'popover', class: '', id: 'staff_experience',
            data: {html: true, placement: 'bottom', title: "Кто? И сколько работает в компании?"}
  end

  def header_link_to_birthdays
    link_to image_tag('cake.svg'), '#', rel: 'popover', class: 'hidden', id: 'birthday_announcements',
            data: {html: true, placement: 'bottom', title: 'Дни рождения'}
  end
end