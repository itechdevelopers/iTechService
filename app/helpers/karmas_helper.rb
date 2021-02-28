module KarmasHelper

  def karma_comment(karma)
    content_tag(:span) do
      concat content_tag(:span, "#{karma.user_presentation} [#{l karma.created_at, format: :date_short}]")
      concat tag(:br)
      concat content_tag(:span, karma.comment)
    end.html_safe
  end

  def link_to_add_karma(user, good, options={})
    link_to new_karma_path(karma: { user_id: user.id, good: good }),
            class: "new_karma_link #{good ? 'good' : 'bad'} #{options[:class]}",
            remote: true,
            id: "new_#{good ? 'good' : 'bad'}_karma_for_#{user.id}" do
      image_tag("karma_#{good ? 'good' : 'bad'}.png")
    end
  end

  def header_karma_button
    title = "#{button_to_close_popover} #{t('users.add_karma')}".gsub('/n', '')
    # content_tag(:span, id: 'header_karma_button') do
      link_to "#{glyph('thumbs-up')}/#{glyph('thumbs-down')}".html_safe, '#', rel: 'popover', id: 'header_karma_link', data: { html: true, placement: 'bottom', title: title, content: header_karma_form.gsub('/n', '') }
    # end
  end

  def header_karma_form
    users_list = User.active.map { |user| [user.short_name, user.id] }
    form_tag(karmas_path, method: :post, remote: true, id: 'header_karma_form') do
      select(:karma, :user_id, users_list, { include_blank: true }) +
      hidden_field(:karma, :good, id: 'header_karma_good') +
      content_tag(:div, class: 'btn-group', 'data-toggle' => 'buttons-radio') do
        button_tag(glyph('thumbs_up'), class: 'btn btn-success', id: 'header_karma_good_true', type: 'button') +
        button_tag(glyph('thumbs_down'), class: 'btn btn-danger', id: 'header_karma_good_false', type: 'button')
      end +
      "<textarea id='karma_comment' name='karma[comment]' rows='3'></textarea>".html_safe +
      button_tag(glyph(:save)+' '+t(:save), class: 'btn btn-primary')
    end
  end

  def karma_group_content(karma_group)
    render(karma_group.karmas.created_asc)
  end

  def karma_group_title(karma_group)
    button_to_close_popover(data: {owner: "#karma_group_#{karma_group.id}"}) +
    (karma_group.is_used? ? '' : link_to(glyph(:trash), karma_group, method: 'delete', remote: true, data: {confirm: t('helpers.links.confirm', default: 'Are you sure?')}, class: 'destroy_karma_group btn btn-mini btn-danger') + link_to(t('karmas.change_for_bonus'), edit_karma_group_path(karma_group), remote: true, class: 'new_bonus_link btn btn-primary btn-mini'))
  end

end
