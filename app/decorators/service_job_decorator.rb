class ServiceJobDecorator < ApplicationDecorator
  delegate_all
  delegate :service_job_path, :client_path, :service_job_subscription_path, to: :helpers

  def device

  end

  def presentation
    [device_name, serial_number, imei].join(' / ')
  end

  def presentation_ticket
    [presentation, ticket_number].join(' / ')
  end

  def presentation_link
    link_to presentation, service_job_path(object)
  end

  def device_name
    (object.item.present? ? object.item.name : object.type_name) || '?'
  end

  def serial_number
    (object.item.present? ? object.item.serial_number : object.serial_number) || '?'
  end

  def imei
    (object.item.present? ? object.item.imei : object.imei) || '?'
  end

  def data_storages
    if object.data_storages.present?
      object.data_storages.map do |storage_name|
        h.content_tag(:span, storage_name, class: 'data_storage-label')
      end.join(' ').html_safe
    else
      '-'
    end
  end

  def creation_date
    I18n.l object.created_at, format: :date_time
  end

  def client_presentation
    client.presentation
  end

  def client_presentation_link
    link_to service_job.client_presentation, client_path(service_job.client)
  end

  def menu_class
    done_at.present? ? 'elqueue-menu-done-job' : 'elqueue-menu-pending-job'
  end

  def subscription_button
    button_class = 'service_job-subscription-button btn btn-small btn-default'
    if object.subscribers.exists? current_user.id
      icon_name = 'star'
      form_method = :delete
      hint = I18n.t 'service_jobs.unsubscribe'
    else
      icon_name = 'star-o'
      form_method = :post
      hint = I18n.t 'service_jobs.subscribe'
    end
    form_for :subscription, url: service_job_subscription_path(object), method: form_method, remote: true,
             html: {class: 'button_to service_job-subscription-form'} do |_|
      button_tag glyph(icon_name), class: button_class, title: hint
    end
  end
end
