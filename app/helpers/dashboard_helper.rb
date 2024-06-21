# frozen_string_literal: true

module DashboardHelper
  def service_job_information_content(service_job)
    if service_job.present?
      (tag(:hr) +
          content_tag(:dl, class: 'dl-horizontal') do
            content_tag(:dt, ServiceJob.human_attribute_name(:client))
            content_tag(:dd, @service_job.client_presentation)
          end
      ).html_safe
    else
      t('service_jobs.not_found', default: 'Service job not found')
    end
  end

  def link_to_edit_service_job(service_job)
    link_to icon_tag(:edit), edit_service_job_path(service_job), class: 'btn btn-small', remote: true
    # , disabled: !is_movable_device?(service_job)
  end

  def link_to_edit_device_task(device_task)
    link_to icon_tag('edit'), edit_device_task_path(device_task), class: 'btn btn-small', remote: true,
                                                                  disabled: !policy(device_task).edit?
  end

  def link_to_edit_device_task_colored(device_task)
    link_to icon_tag('edit'), edit_device_task_path(device_task), remote: true,
                                                                  disabled: !policy(device_task).edit?
  end

  def is_actual_service_job?(service_job)
    service_job.is_actual_for?(current_user)
  end

  def is_movable_service_job?(service_job)
    current_user.any_admin? ? true : service_job.is_actual_for?(current_user)
  end

  def is_actual_task?(device_task)
    current_user.role_match?(device_task.role) ||
      current_user.code_match?(device_task.code)
  end

  def service_job_row_tag(service_job)
    content_tag(:tr, class: 'info service_job_row', data: { service_job_id: service_job.id }) do
      content_tag(:td, device_movement_information_tag(service_job), class: 'device_movement_column') +
        content_tag(:td, class: 'device_task_column') do
          c = ''.html_safe
          c += content_tag(:span, service_job.progress,
                           class: "device_tasks_toggle #{progress_badge_class_for_service_job(service_job)}")
          c += link_to(service_job.presentation, service_job_path(service_job))
          c += service_job_row_tag_device_attribute(service_job, [:ticket_number])
          spoiler = service_job_row_tag_device_attribute(service_job, %i[claimed_defect device_condition client_comment
                                                                         type_of_work estimated_cost_of_repair])
          c += content_tag(:details, spoiler) unless spoiler.blank?
          c
        end +
        content_tag(:td, class: 'client_comment_column') do
          (if service_job.client.present?
             link_to(service_job.client_short_name,
                     client_path(service_job.client))
           else
             '-'
           end).html_safe +
            " #{contact_phones_for(service_job)}".html_safe +
            tag(:br, false) +
            service_job.note
        end +
        content_tag(:td, class: 'device_task_action_column') do
          notes_icon_name = service_job.device_notes.exists? ? 'file-text-o' : 'file-o'
          link_to_edit_service_job(service_job) +
            link_to(glyph(notes_icon_name), service_job_device_notes_path(service_job),
                    class: 'device_notes-button btn btn-small', remote: true) +
            service_job.decorate.subscription_button +
            button_to_set_keeper_of_device(service_job)
        end
    end
  end

  def service_job_row_tag_device_attribute(service_job, attributes = [])
    res = ActiveSupport::SafeBuffer.new
    attributes.each do |attr|
      next if (attr_value = service_job.send(attr)).blank?

      res += tag(:br, false)
      res += content_tag(:strong, class: "device_#{attr}") { "#{ServiceJob.human_attribute_name(attr)}: " }
      res += content_tag(:span) { attr_value }
    end
    res
  end

  def ready_service_job_row_tag(service_job)
    content_tag(:tr, class: 'service_job_row', data: { service_jobs_id: service_job.id }) do
      content_tag(:td, device_movement_information_tag(service_job), class: 'device_movement_column') +
        content_tag(:td) do
          link_to(service_job.presentation, service_job_path(service_job)) +
            tag(:br, false) +
            content_tag(:span, class: 'device_ticket_number') do
              "#{ServiceJob.human_attribute_name(:ticket_number)}: #{service_job.ticket_number}"
            end
        end +
        content_tag(:td) do
          link_to(service_job.client_presentation, client_path(service_job.client)) +
            tag(:br, false) +
            service_job.comment
        end +
        content_tag(:td, service_job.done_at.present? ? l(service_job.done_at, format: :date_time) : '-') +
        content_tag(:td, link_to_edit_service_job(service_job))
    end
  end

  def device_task_row_tag(device_task)
    content_tag(:tr, class: "device_task_row #{device_task.done_s} #{'actual' if is_actual_task?(device_task)}",
                     data: { device_task_id: device_task.id, service_job_id: device_task.service_job.id, task_id: device_task.task.id }) do
      content_tag(:td, nil) +
        content_tag(:td, device_task.task_name) +
        content_tag(:td) do
          content_tag(:span, h(device_task.comment)) +
            tag(:br) +
            content_tag(:strong, h(device_task.user_comment), class: 'user_comment').html_safe
        end +
        content_tag(:td, policy(device_task).edit? ? link_to_edit_device_task(device_task) : nil)
    end.html_safe
  end

  def prepayment_details_content(details)
    content_tag(:table, class: 'table table-condensed') do
      details.map do |detail|
        content_tag(:tr) do
          content_tag(:td, detail[:date].strftime('%d.%m.%y')) +
            content_tag(:td, detail[:amount]) +
            content_tag(:td, detail[:comment])
        end
      end.join.html_safe
    end.gsub('\n', '')
  end

  def installment_details_content(details)
    content_tag(:table, class: 'table table-condensed') do
      details.map do |detail|
        content_tag(:tr) do
          content_tag(:td, detail[:date].strftime('%d.%m.%y')) +
            content_tag(:td, detail[:value]) +
            content_tag(:td, detail[:object])
        end
      end.join.html_safe
    end.gsub('\n', '')
  end

  def jobs_count_by_group_and_location(product_group, location = nil)
    jobs = location.present? ?
           ServiceJob.pending.located_at(location) :
           ServiceJob.pending
    jobs.of_product_group(product_group).count.to_s
  end
end
