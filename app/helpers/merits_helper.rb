module MeritsHelper
  def header_merit_button
    link_to glyph('plus-circle'), new_merit_path, remote: true, id: 'header-merit-link'
  end

  def merit_recipients_collection
    User.active.staff.order(:name)
  end
end
