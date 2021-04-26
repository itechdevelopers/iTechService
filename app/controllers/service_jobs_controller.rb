# frozen_string_literal: true

class ServiceJobsController < ApplicationController
  include ServiceJobsHelper
  helper_method :sort_column, :sort_direction
  skip_before_action :authenticate_user!, :set_current_user, only: :check_status
  skip_after_action :verify_authorized, only: %i[index check_status device_type_select quick_search]

  def index
    @service_jobs = policy_scope(ServiceJob)
    @service_jobs = ServiceJobFilter.call(collection: @service_jobs, **filter_params).collection

    if params.key? :search
      @service_jobs = @service_jobs.search(params[:search])
      unless params[:search][:location_id].blank?
        @location_name = Location.select(:name).find(params[:search][:location_id]).name
      end
    end

    unless params.key?(:search) || params.key?(:filter)
      @service_jobs = @service_jobs.send(params[:location] == 'archive' ? :at_archive : :not_at_archive)
      @service_jobs = @service_jobs.in_department(current_department)
    end

    @service_jobs = @service_jobs.reorder("service_jobs.#{sort_column} #{sort_direction}") if params.key?(:sort)
    @service_jobs = @service_jobs.newest

    @service_jobs = @service_jobs.page params[:page]
    @locations = current_department.locations.visible

    respond_to do |format|
      format.html
      format.json { render json: @service_jobs }
      format.js { render 'shared/index', locals: { resource_table_id: 'service_jobs_table' } }
    end
  end

  def stale
    authorize ServiceJob

    @lists = [
      {
        title: 'В готово больше трёх месяцев',
        jobs: ServiceJob.stale_at_done_over(3)
      },
      {
        title: 'В готово больше года',
        jobs: ServiceJob.stale_at_done_over(12)
      }
    ]

    respond_to do |format|
      format.js
    end
  end

  def show
    if params[:find] == 'ticket'
      @service_job = authorize ServiceJob.find_by_ticket_number(params[:id])
      respond_to do |format|
        format.js do
          if @service_job.present?
            log_viewing
            render 'ticket_scan'
          else
            flash.now[:error] = t('service_jobs.not_found_by_ticket', ticket: params[:id])
          end
        end
      end
    else
      @service_job = find_record ServiceJob.includes(:device_notes)
      @device_note = @service_job.device_notes.build(user_id: current_user.id)
      respond_to do |format|
        format.html { log_viewing }
        format.json do
          log_viewing
          render json: @service_job
        end
        format.pdf do
          if can? :print_receipt, @service_job
            filename = "ticket_#{@service_job.ticket_number}.pdf"
            if params[:print]
              pdf = TicketPdf.new @service_job, view_context
              filepath = "#{Rails.root}/tmp/pdf/#{filename}"
              pdf.render_file filepath
              PrinterTools.print_file filepath, type: :ticket, printer: current_department.printer
            else
              pdf = TicketPdf.new @service_job, view_context, params[:part]
            end
            send_data pdf.render, filename: filename, type: 'application/pdf', disposition: 'inline'
          else
            render nothing: true
          end
        end
      end
    end
  end

  def new
    params = service_job_params rescue {}
    @service_job = authorize ServiceJob.new(params)
    @service_job.department_id = current_user.department_id

    respond_to do |format|
      format.html { render_form }
      format.json { render json: @service_job }
    end
  end

  def edit
    @service_job = find_record ServiceJob.includes(:device_notes)
    build_device_note
    log_viewing
    respond_to do |format|
      format.html { render_form }
      format.js { render 'shared/show_modal_form' }
    end
  end

  def create
    @service_job = authorize ServiceJob.new(service_job_params)
    @service_job.initial_department = current_user.department
    respond_to do |format|
      if @service_job.save
        create_phone_substitution if @service_job.phone_substituted?
        Service::Feedback::Create.call(service_job: @service_job)
        format.html { redirect_to @service_job, notice: t('service_jobs.created') }
        format.json { render json: @service_job, status: :created, location: @service_job }
      else
        format.html { render_form }
        format.json { render json: @service_job.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @service_job = ServiceJob.find(params[:id])
    the_policy = policy(@service_job)

    if the_policy.update?
      @service_job.attributes = params_for_update
      skip_authorization
    elsif the_policy.move_transfers?
      @service_job.attributes = params_for_update.slice(:location_id, :client_notified)
      skip_authorization
    else
      raise Pundit::NotAuthorizedError, query: 'update', record: @service_job, policy: the_policy
    end

    build_device_note

    respond_to do |format|
      if @service_job.save
        create_phone_substitution if @service_job.phone_substituted?
        Service::DeviceSubscribersNotificationJob.perform_later @service_job.id, current_user.id, params
        format.html { redirect_to @service_job, notice: t('service_jobs.updated') }
        format.json { head :no_content }
        format.js { render 'update' }
      else
        format.html { render_form }
        format.json { render json: @service_job.errors, status: :unprocessable_entity }
        format.js { render 'shared/show_modal_form' }
      end
    end
  end

  def destroy
    service_job = find_record ServiceJob

    if service_job.repair_parts.any?
      flash.alert = 'Работа не может быть удалена (привязаны запчасти).'
    else
      service_job_presentation = "[Талон: #{service_job.ticket_number}] #{service_job.decorate.presentation}"
      DeletionMailer.notice({
                              presentation: service_job_presentation,
                              tasks: service_job.tasks.map(&:name).join(', '),
                              reason: params[:reason]
                            },
                            current_user.presentation,
                            I18n.l(Time.current, format: :date_time)).deliver_later

      if service_job.destroy
        flash.notice = 'Работа удалена!'
      else
        flash.alert = 'Работа не удалена!'
      end
    end

    respond_to do |format|
      format.html { redirect_to(request.referrer || service_jobs_url) }
      format.json { head :no_content }
    end
  end

  def work_order
    respond_to do |format|
      service_job = find_record ServiceJob
      pdf = WorkOrderPdf.new service_job, view_context
      filename = "work_order_#{service_job.ticket_number}.pdf"
      format.pdf { send_data pdf.render, filename: filename, type: 'application/pdf', disposition: 'inline' }
    end
  end

  def completion_act
    respond_to do |format|
      service_job = find_record ServiceJob
      pdf = CompletionActPdf.new service_job, view_context
      filename = "completion_act_#{service_job.ticket_number}.pdf"
      format.pdf { send_data pdf.render, filename: filename, type: 'application/pdf', disposition: 'inline' }
    end
  end

  def history
    service_job = find_record ServiceJob
    @records = service_job.history_records
    render 'shared/show_history'
  end

  def task_history
    service_job = authorize ServiceJob.find(params[:service_job_id])
    device_task = DeviceTask.find(params[:id])
    @records = device_task.history_records
    render 'shared/show_history'
  end

  # TODO
  def device_type_select
    if params[:device_type_id].blank?
      render 'device_type_refresh'
    else
      @device_type = DeviceType.find(params[:device_type_id])
      render 'device_type_select'
    end
  end

  def check_status
    @service_job = ServiceJob.find_by_ticket_number(params[:ticket_number])

    respond_to do |format|
      if @service_job.present?
        format.js { render 'information' }
        format.json { render text: "deviceStatus({'status':'#{@service_job.status}'})" }
      else
        format.js { render t('service_jobs.not_found') }
        format.json { render js: "deviceStatus({'status':'not_found'})" }
      end
    end
  end

  def check_imei
    item = Item.find(params[:item_id])
    msg = ''
    stolen_phone = nil

    if item.imei.present?
      stolen_phone = StolenPhone.by_imei(item.imei).first
      msg = t('devices.phone_stolen') if stolen_phone.present?
    end
    render json: { present: stolen_phone.present?, msg: msg }
  end

  # TODO
  def device_select
    @service_job = ServiceJob.find params[:service_jobs_id]
  end

  def movement_history
    @service_job = find_record ServiceJob
  end

  def create_sale
    service_job = find_record ServiceJob
    respond_to do |format|
      if service_job.department == current_department
        if service_job.sale.present?
          if service_job.sale.is_new?
            format.html { redirect_to edit_sale_path(service_job.sale) }
          else
            format.html { redirect_to service_job.sale }
          end
        elsif (sale = service_job.create_filled_sale).present?
          format.html { redirect_to edit_sale_path(sale) }
        else
          format.html { render nothing: true }
        end
      else
        format.html { render text: 'Вы находитесь на разных подразделениях с устройством. Смените подразделение' }
      end
    end
  end

  def quick_search
    @service_jobs = policy_scope(ServiceJob).quick_search(params[:quick_search])
    respond_to do |format|
      format.js { render nothing: true if @service_jobs.count > 10 }
    end
  end

  def set_keeper
    @service_job = find_record ServiceJob
    new_keeper_id = @service_job.keeper == current_user ? nil : current_user.id
    @service_job.update_attribute :keeper_id, new_keeper_id
    respond_to do |format|
      format.js
    end
  end

  def archive
    @service_job = find_record ServiceJob
    respond_to do |format|
      if @service_job.archive
        make_review_url
        format.js
      else
        format.js { render_error @service_job.errors.full_messages }
      end
    end
  end

  private

  def make_review_url
    return unless current_user.able_to?(:request_review)
    time_out = Setting.request_review_time_out(service_job.department) * 60
    review = Review.create(
      service_job: @service_job,
      client: @service_job.client,
      phone: @service_job.client.full_phone_number,
      token: SecureRandom.urlsafe_base64
    )
    SendSmsWithReviewUrlJob.perform_later(review.id, wait: time_out)
  rescue
    nil
  end

  def build_device_note
    @device_note = DeviceNote.new user_id: current_user.id, service_job_id: @service_job.id
  end

  def sort_column
    ServiceJob.column_names.include?(params[:sort]) ? params[:sort] : ''
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : 'asc'
  end

  def generate_barcode_to(pdf, num)
    # require 'barby'
    require 'barby/barcode/ean_13'
    require 'barby/outputter/prawn_outputter'
    require 'barby/outputter/pdfwriter_outputter'

    code = '0' * (12 - num.length) + num
    code = Barby::EAN13.new code
    out = Barby::PrawnOutputter.new code
    out.to_pdf document: pdf
  end

  def log_viewing
    ServiceJobViewing.create(service_job: @service_job, user: current_user, time: Time.current, ip: request.ip)
  end

  def create_phone_substitution
    PhoneSubstitution.create_with(issuer_id: current_user.id, issued_at: Time.current).find_or_create_by(
      service_job_id: @service_job.id, substitute_phone_id: @service_job.substitute_phone_id, withdrawn_at: nil
    )
  end

  def render_form
    set_job_templates
    render 'form'
  end

  def set_job_templates
    @job_templates = Service::JobTemplate.select(:field_name, :content).all.to_a.group_by(&:field_name)
  end

  def service_job_params
    params.require(:service_job).permit(
      :app_store_pass, :carrier_id, :case_color_id, :claimed_defect, :client_address, :client_comment,
      :client_id, :client_notified, :comment, :completeness, :contact_phone, :department_id,
      :device_condition, :device_group, :device_type_id, :done_at, :email, :estimated_cost_of_repair, :imei,
      :initial_department_id, :is_tray_present, :item_id, :keeper_id, :location_id, :notify_client,
      :replaced, :return_at, :sale_id, :security_code, :serial_number, :status, :tech_notice,
      :ticket_number, :trademark, :type_of_work, :user_id, :substitute_phone_id, :substitute_phone_icloud_connected,
      data_storages: []
    ).tap do |p|
      p[:device_tasks_attributes] = params[:service_job][:device_tasks_attributes].permit! if params[:service_job][:device_tasks_attributes]
    end
  end

  def params_for_update
    allowed_params = service_job_params
    if allowed_params.key?(:device_tasks_attributes)
      allowed_params[:device_tasks_attributes].each do |_key, device_task_attributes|
        if device_task_attributes.key?(:id)
          device_task = DeviceTask.find(device_task_attributes[:id])
          device_task_attributes[:_destroy] = false if device_task.repair_parts.any?
        end
      end
    end
    allowed_params
  end
end
