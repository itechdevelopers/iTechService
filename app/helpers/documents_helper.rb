module DocumentsHelper

  def document_presentation(document)
    t 'document', name: t("activerecord.models.#{document.class.to_s.underscore}"), num: document.id, time: human_datetime(document.created_at)
  end

  def status_presentation(document)
    if (status = document.try(:status_s)).present?
      t "documents.statuses.#{status}"
    else
      '-'
    end
  end

  def button_to_post(document)
    link_to "#{glyph('check')} #{t('post')}".html_safe, {controller: document.class.to_s.tableize, action: 'post', id: document.id}, method: :patch, data: {confirm: t('confirmation')}, class: 'btn btn-primary'
  end

  def button_to_unpost(document)
    link_to "#{glyph('square-o')} #{t('unpost')}".html_safe, {controller: document.class.to_s.tableize, action: 'unpost', id: document.id}, method: :patch, data: {confirm: t('confirmation')}, class: 'btn btn-primary'
  end

  def document_row_class(document)
    case document.status
      when 0 then 'info'
      when 1 then 'success'
      when 2 then 'error'
    end
  end

end