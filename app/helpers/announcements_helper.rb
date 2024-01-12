module AnnouncementsHelper

  def announcement_content announcement
    user_name = announcement.user.try(:short_name)
    case announcement.kind
      when 'help' then text = "#{user_name} #{t('announcements.needs_help')}"
      when 'coffee' then text = "#{user_name}: #{t('announcements.coffee_made')}"
      when 'for_coffee' then text = "#{user_name}: #{t('announcements.coffee_order', content: announcement.content)}"
      when 'protector' then text = "#{user_name}: #{t('announcements.protector_made')}"
      when 'bad_review'
        text = ''
        if (review = announcement.review).present?
          ticket_number = ServiceJob.find(review.service_job_id).ticket_number
          text = t('announcements.bad_review', rating: review.value, number: ticket_number)
        end
      when 'birthday'
        text = ''
        if (birthday = announcement.user.try(:birthday)).present?
          text = t('announcements.birthday', user: user_name, time: l(birthday, format: :short))
        end
      when 'order_status' then text = announcement.content
      when 'order_done' then text = announcement.content
      when 'device_return'
        if (service_job = announcement.service_job).present?
          time = l(service_job.return_at, format: service_job.return_at.today? ? :time : :short_r)
          dist = (service_job.return_at - Time.current) / 60
          term = dist > 0 ? humanize_duration(dist) : humanize_duration(0)
          text = t('announcements.device_return', time: time, service_job: service_job.type_name, ticket: service_job.ticket_number, term: term)
        else
          text = ''
        end
      else text = "#{user_name}: #{announcement.content}"
    end
    content_tag(:div, l(announcement.created_at, format: :date_time), class: 'timestamp') +
    content_tag(:div, text)
  end

  def header_link_to_announce
    case current_user.role
      when 'software' then icon = 'bell-alt'; kind = 'help'
      when 'media' then icon = 'coffee'; kind = 'coffee'
      when 'technician' then icon = 'file'; kind = 'protector'
      else return nil
    end
    if current_user.announced?
      state_class = 'active'
      link_path = cancel_announce_path(kind: kind)
    else
      state_class = ''
      link_path = make_announce_path(kind: kind)
    end
    # content_tag(:li, id: 'announce_button', class: state_class) do
      link_to glyph(icon), link_path, method: :post, remote: true, id: 'announce_link', class: state_class
    # end.html_safe
  end

  def header_link_for_coffee
    if current_user.software?
      coffee_order_form = form_tag(make_announce_path, remote: true, id: 'coffee_order_form', class: 'form-inline') do
        content_tag(:div, class: 'input-append') do
          hidden_field_tag(:user, current_user) +
          hidden_field_tag(:kind, 'for_coffee') +
          text_field_tag(:content, nil, class: 'input-medium', autofocus: true) +
          submit_tag('OK', class: 'btn btn-primary')
        end +
        link_to(t('announcements.close_orders'), cancel_announce_path(kind: 'for_coffee'), method: :post, remote: true,
                class: 'btn btn-small')
      end.gsub('\n', '')

      # content_tag(:li, id: 'coffee_order_button') do
        link_to glyph('coffee'), '#', rel: 'popover', id: 'coffer_order_link', data: {html: true, placement: 'bottom', title: t('announcements.coffee_order_popover_title'), content: coffee_order_form}
      # end
    else
      nil
    end
  end

  def any_bad_reviews?
    can?(:see_bad_reviews, Announcement) && Announcement.active_bad_reviews.map(&:recipients).flatten.include?(current_user)
  end
end
