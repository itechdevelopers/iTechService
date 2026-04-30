module SalesHelper

  def options_for_sale_kind_select(kind=false)
    options_for_select %w[sale return return_check].map { |k| [t("sales.kinds.#{k}"), k] }, kind
  end

  def link_to_save_sale(sale)
    if sale.new_record? or !sale.is_new?
      link_to t('sales.save_check'), '#', id: 'sale_save_check', class: 'btn btn-primary', disabled: true
    else
      link_to t('sales.save_check'), '#', id: 'sale_save_check', class: 'btn btn-primary'
    end
  end

  def link_to_post_sale(sale)
    name = image_tag('close_check_w.png') + t('sales.close_check').html_safe
    if !sale.is_postable?
      link_to name, '#', id: 'sale_close_check', class: 'btn btn-danger', disabled: true
    elsif sale.is_return? and sale.needs_gift_certificate?
      link_to t('sales.attach_gift_certificate'), '#', id: 'sale_close_check', class: 'btn btn-danger attach_gift_certificate'
    else
      link_to name, post_sale_path(sale), method: :patch, id: 'sale_close_check', class: 'btn btn-danger', data: {confirm: t('confirmation')}
    end
  end

  def link_to_cancel_sale(sale)
    name = image_tag('cancel_check_w.png') + t('sales.cancel_check').html_safe
    if sale.new_record? or !sale.is_new?
      link_to name, '#', id: 'sale_cancel_check', class: 'btn btn-primary', disabled: true
    else
      link_to name, cancel_sale_path(sale), method: 'post', id: 'sale_cancel_check', class: 'btn btn-primary'
    end
  end

  def link_to_print_warranty(sale)
    name = image_tag('warranty_print_w.png')+t('sales.print_warranty').html_safe
    if sale.new_record?
      link_to name, '#', class: 'btn btn-info', disabled: true
    else
      link_to name, print_warranty_sale_path(@sale, format: :pdf), class: 'btn btn-info', target: '_blank'
    end
  end

  def link_to_payment(sale)
    name = image_tag('rub_w.png') + t('sales.payment').html_safe
    if sale.new_record? or sale.sale_items.empty?
      link_to name, '#', id: '', class: 'btn btn-success', disabled: true
    elsif sale.payments.any?
      link_to name, sale_payments_path(sale_id: sale.id), remote: true, id: '', class: 'btn btn-success'
    else
      content_tag(:div, class: 'btn-group dropup') do
        link_to(name + content_tag(:span, nil, class: 'caret'), '#', class: 'btn dropdown-toggle btn-success', 'data-toggle' => 'dropdown') +
        content_tag(:ul, class: 'dropdown-menu') do
          content_tag(:li, link_to(t('payments.kinds.mixed'), sale_payments_path(sale_id: sale.id), remote: true)) +
          content_tag(:li, nil, class: 'divider') +
          content_tag(:li, link_to(t('payments.kinds.certificate'), new_sale_payment_path(sale_id: sale.id, payment: {kind: 'certificate', value: sale.calculation_amount}), remote: true)) +
          content_tag(:li, link_to(t('payments.kinds.credit'), new_sale_payment_path(sale_id: sale.id, payment: {kind: 'credit', value: sale.calculation_amount}), remote: true)) +
          content_tag(:li, link_to(t('payments.kinds.card'), new_sale_payment_path(sale_id: sale.id, payment: {kind: 'card', value: sale.calculation_amount}), remote: true)) +
          content_tag(:li, link_to(t('payments.kinds.cash'), sale_payments_path(sale_id: sale.id, payment: {kind: 'cash', value: sale.calculation_amount}), method: :post, remote: true, rel: 'nofollow')) +
          content_tag(:li, link_to(t('payments.kinds.qr'), sale_payments_path(sale_id: sale.id, payment: {kind: 'qr', value: sale.calculation_amount}), method: :post, remote: true, rel: 'nofollow')) +
          content_tag(:li, link_to(t('payments.kinds.invoice'), new_sale_payment_path(sale_id: sale.id, payment: {kind: 'invoice', value: sale.calculation_amount}), remote: true))
        end
      end
    end
  end

  def link_to_add_payment(append_to_selector, f)
    new_payment = Payment.new client_info: f.object.client_presentation
    fields = f.fields_for(:payments, new_payment, child_index: 'new_payments') do |builder|
      render('payments/payment_fields', f: builder, index: 'new_payments')
    end
    link_to glyph('plus') + t('payments.add').html_safe, '#', class: 'add_fields add_payment btn btn-success btn-small', data: { selector: append_to_selector, association: 'payments', content: (fields.gsub('\n', '')) }
  end

  def link_to_manual_discount(sale)
    name = image_tag('discount_w.png') + t('sales.manual_discount').html_safe
    if sale.new_record? or !sale.is_new? or sale.sale_items.empty?
      link_to name, '#', id: 'sale_set_manual_discount', class: 'btn btn-info', disabled: true
    else
      link_to name, edit_sale_path(sale, form_name: 'discount_form'), remote: true, id: 'sale_set_manual_discount', class: 'btn btn-info'
    end
  end

  def sale_row_class(sale)
    case sale.status
      when 0 then 'info'
      when 1 then sale.is_return ? 'error' : 'success'
      when 2 then 'warning'
      else ''
    end
  end

  def sale_title(sale)
    t("sales.#{sale.is_return ? 'title_return' : 'title'}", num: sale.id, datetime: human_datetime(sale.date))
  end

end