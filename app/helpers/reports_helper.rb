module ReportsHelper

  def report_title(report)
    t("reports.#{report.is_a?(String) ? report : report.name}.title")
  end

  def report_names
    %w[
      device_groups
      users
      devices_archived
      devices_not_archived
      active_tasks
      done_tasks
      done_tasks_copy
      clients
      tasks_duration
      device_orders
      orders_statuses
      devices_movements
      payments
      salary
      driver
      few_remnants_goods
      few_remnants_spare_parts
      body_repair_jobs
      repair_jobs
      technicians_jobs
      technicians_difficult_jobs
      repairers
      remnants
      sales
      margin
      quick_orders
      free_jobs
      phone_substitutions
      sms_notifications
      service_jobs_at_done
      repair_parts
      defected_spare_parts
      service_job_viewings
      contractors_defected_spare_parts
      uniform
      repeated_repair
      repeated_repair2
      users_jobs
      mac_service
      warranty_repair_parts
      spare_part_movements
      client_reviews
    ].freeze
  end

  def report_default_params(report_name, annotation = nil)
    result = {
      few_remnants_goods: {base_name: 'few_remnants', kind: 'goods'},
      few_remnants_spare_parts: {base_name: 'few_remnants', kind: 'spare_parts'}
    }.fetch report_name.to_sym, {base_name: report_name}
    result[:annotation] = annotation if annotation
    result
  end

  def remnants_row(data)
    row_class = data[:type]
    row_class << ' detailable' if data[:details].any?
    row_class << ' details' if data[:depth] > 0
    content = ''
    if data[:quantity] > 0
      content << content_tag(:tr, class: row_class, data: {depth: data[:depth], id: data[:id]}) do
        content_tag(:td, data[:code], class: 'code') +
        content_tag(:td, data[:name], class: 'name') +
        content_tag(:td, data[:quantity], class: 'quantity number') +
        content_tag(:td, human_currency(data[:purchase_price], false), class: 'price number') +
        content_tag(:td, human_currency(data[:purchase_sum], false), class: 'price number') +
        content_tag(:td, human_currency(data[:price], false), class: 'price number') +
        content_tag(:td, human_currency(data[:sum], false), class: 'sum number')
      end.html_safe
    end
    content << data[:details].collect do |detail|
      remnants_row detail
    end.join
    content.html_safe
  end

  def departments_collection(selected)
    option_groups_from_collection_for_select City.all, :departments, :name, :id, :name, selected
  end

  def stores_collection(selected)
    option_groups_from_collection_for_select Department.all, :stores, :full_name, :id, :name, selected
  end

  def locations_collection(selected)
    option_groups_from_collection_for_select Department.all, :locations, :full_name, :id, :name, selected
  end

  def users_collection(selected)
    options_from_collection_for_select User.active.staff.order(:name), :id, :full_name, selected
  end

  def spare_parts_collection
    option_groups_from_collection_for_select ProductGroup.spare_parts.where(ancestry_depth: 2).reorder(:ancestry, position: :asc),
      :products,
      :flatten_name,
      :id,
      :name
  end

  def url_for_movement(type, id)
    res_url = ""
    case type
    when "purchase"
      res_url = purchase_path(id: id)
    when "movement_act"
      res_url = movement_act_path(id: id)
    when "deduction_act"
      res_url = deduction_act_path(id: id)
    when "service_job"
      res_url = service_job_path(id: id)
    end

    res_url
  end

  def optional_link_to(href)
    href.present? ? link_to('Ссылка', href, target: '_blank') : ''
  end
end
