module TopBarHelper
  # Сколько заждавшихся диалогов показывать во всплывашке. Это не список задач,
  # а подсказка «что горит» — за остальным человек идёт в раздел.
  CLIENT_CONVERSATIONS_POPOVER_LIMIT = 5

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

  # Иконка «Ой» → страница «Кря-контроль». Видимость делегирована политике,
  # чтобы не расходиться с доступом к самой странице (QuackControlPolicy#show?:
  # сотрудник на ремонтной локации или супер-админ).
  def header_link_to_quack_control
    return unless policy(:quack_control).show?

    link_to t('quack_control.icon_label'), quack_control_path,
            class: 'quack-control__nav-icon', title: t('quack_control.show.title')
  end

  def header_link_to_birthdays
    link_to image_tag('cake.svg'), '#', rel: 'popover', class: 'hidden', id: 'birthday_announcements',
            data: {html: true, placement: 'bottom', title: 'Дни рождения'}
  end

  def header_link_to_bad_reviews
    link_to image_tag('bad-review.svg'), '#', rel: 'popover', class: 'hidden', id: 'bad_review_announcements',
            data: {html: true, placement: 'bottom', title: 'Негативные отзывы'}
  end

  # Иконка «Диалоги с клиентами» со счётчиком необработанных. Видимость
  # делегирована политике, чтобы не расходиться с доступом к самому разделу.
  #
  # Показываем состояние (сколько диалогов ждут ответа сейчас), а не журнал
  # событий: ответил один сотрудник — число падает у всех само, и закрывать
  # уведомления не нужно.
  def header_link_to_client_conversations
    return unless policy(ClientConversation).index?

    count = ClientConversation.awaiting_count_for(current_user)
    link_to client_conversations_path(filter: 'awaiting'),
            id: 'client_conversations_icon', rel: 'popover',
            class: 'client-chat-nav-icon',
            data: { html: true, placement: 'bottom',
                    title: t('client_conversations.index.title'),
                    content: client_conversations_popover_content } do
      safe_join([
        content_tag(:span, '💬', class: 'client-chat-nav-icon__glyph'),
        content_tag(:span, count, id: 'client_conversations_counter',
                                  class: "badge badge-important#{' hidden' if count.zero?}")
      ])
    end
  end

  # Содержимое всплывашки. Строится и при загрузке страницы, и при каждом
  # обновлении счётчика, поэтому живёт отдельным методом.
  def client_conversations_popover_content
    # Свежие сверху, в отличие от страницы, где очередь отсортирована по
    # возрасту ожидания. Всплывашка отвечает на вопрос «что прилетело», а
    # «кто ждёт дольше всех» человек смотрит в разделе.
    conversations = ClientConversation.awaiting_for(current_user)
                                      .order(last_inbound_at: :desc)
                                      .limit(CLIENT_CONVERSATIONS_POPOVER_LIMIT)
                                      .includes(:client).to_a
    render partial: 'client_conversations/popover_list',
           locals: { conversations: conversations,
                     last_messages: ClientConversation.last_messages_for(conversations) }
  end

  def header_link_to_notifications
    link_to "", id: "user_notifications", rel: "popover",
            data: { html: true, placement: "bottom", title: notifications_popover_title } do
      inline_svg("letter.svg")
    end
  end

  private

  def notifications_popover_title
    close_all_btn = link_to(
      glyph(:check),
      close_all_notifications_path,
      remote: true,
      method: :post,
      class: 'notifications-popover__action notifications-popover__action--close-all',
      title: 'Закрыть все уведомления'
    )

    show_all_btn = link_to(
      glyph(:'list-alt'),
      notifications_path(format: :js),
      remote: true,
      class: 'notifications-popover__action notifications-popover__action--show-all',
      title: 'Все уведомления'
    )

    label = content_tag(:span, 'Активные уведомления',
                        class: 'notifications-popover__title-label')
    actions = content_tag(:span,
                          safe_join([close_all_btn, show_all_btn]),
                          class: 'notifications-popover__title-actions')

    (label + actions).to_s
  end
end