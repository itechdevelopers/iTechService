# frozen_string_literal: true

class ServiceJobsController < ApplicationController
  include ServiceJobsHelper
  include CheckListsHelper

  helper_method :sort_column, :sort_direction

  skip_before_action :authenticate_user!, :set_current_user, only: :check_status
  skip_after_action :verify_authorized, only: %i[index check_status device_type_select quick_search]

  def index
    @service_jobs = policy_scope(ServiceJob)
    @service_jobs = ServiceJobFilter.call(collection: @service_jobs, **filter_params).collection

    if params.key? :search
      @service_jobs = @service_jobs.search(search_params)
      unless search_params[:location_id].blank?
        @location_name = Location.select(:name).find(search_params[:location_id]).name
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
    query = ServiceJobsQuery.new

    @lists = [
      {
        title: 'В готово больше трёх месяцев',
        jobs: query.stale_at_done_over(3)
      },
      {
        title: 'В готово больше года',
        jobs: query.stale_at_done_over(12)
      }
    ]

    respond_to(&:js)
  end

  def show_qr
    @division = params[:division]
    @service_job = find_record ServiceJob
    generate_qr_link
    respond_to(&:js)
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
      @available_check_lists = available_check_lists_for('ServiceJob')
      respond_to do |format|
        format.html do
          log_viewing
          @same_item_service_jobs = []
          if (item = @service_job.item)
            @same_item_service_jobs = item.service_jobs.where
                                          .not(id: @service_job.id)
                                          .order(created_at: :desc)
                                          .limit(12)
          end
        end
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
            head :no_content
          end
        end
      end
    end
  end

  def new
    new_params = service_job_params rescue {}
    @service_job = authorize ServiceJob.new(new_params)
    @service_job.department_id = current_user.department_id
    prepare_check_list_data

    respond_to do |format|
      format.html { render_form }
      format.json { render json: @service_job }
    end
  end

  def new_v2
    new_params = service_job_params rescue {}
    @service_job = authorize ServiceJob.new(new_params), :new_v2?
    @service_job.department_id = current_user.department_id
    prepare_check_list_data

    respond_to do |format|
      format.html { render_form }
      format.json { render json: @service_job }
    end
  end

  def edit
    @service_job = find_record ServiceJob.includes(:device_notes)
    prepare_check_list_data
    @modal = "service-job-#{@service_job.id}"
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

        processor = CheckListResponsesProcessor.new(@service_job, 'service_job')
        processor.process(params, strategy: :create)

        format.html { redirect_to @service_job, notice: t('service_jobs.created') }
        format.json { render json: @service_job, status: :created, location: @service_job }
      else
        prepare_check_list_data
        format.html { render_form }
        format.json { render json: @service_job.errors, status: :unprocessable_entity }
      end
    end
  end

  def create_v2
    @service_job = authorize ServiceJob.new(service_job_params), :create_v2?
    @service_job.initial_department = current_user.department

    respond_to do |format|
      if @service_job.save
        create_phone_substitution if @service_job.phone_substituted?
        Service::Feedback::Create.call(service_job: @service_job)

        processor = CheckListResponsesProcessor.new(@service_job, 'service_job')
        processor.process(params, strategy: :create)

        format.html { redirect_to @service_job, notice: t('service_jobs.created') }
        format.json { render json: @service_job, status: :created, location: @service_job }
      else
        prepare_check_list_data
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
        if @service_job.in_archive? && Review.where(service_job: @service_job).empty?
          ServiceJobs::MakeReview.call(service_job: @service_job, user: current_user)
        end

        create_phone_substitution if @service_job.phone_substituted?
        Service::DeviceSubscribersNotificationJob.perform_later @service_job.id, current_user.id, notify_params
        
        processor = CheckListResponsesProcessor.new(@service_job, 'service_job')
        processor.process(params, strategy: :update)

        format.html { redirect_to @service_job, notice: t('service_jobs.updated') }
        format.json { head :no_content }
        format.js { render 'update' }
      else
        prepare_check_list_data
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
      redirection_url = request.referrer
    else
      service_job_presentation = "[Талон: #{service_job.ticket_number}] #{service_job.decorate.presentation}"
      tasks = service_job.tasks.map(&:name).join(', ')
      if service_job.destroy
        flash.notice = 'Работа удалена!'
        DeletionMailer.notice({
                                presentation: service_job_presentation,
                                tasks: tasks,
                                reason: params[:reason]
                              },
                              current_user.presentation,
                              I18n.l(Time.current, format: :date_time))
                      .deliver_later
        redirection_url = service_jobs_url
      else
        flash.alert = 'Работа не удалена!'
        redirection_url = request.referrer
      end
    end

    respond_to do |format|
      format.html do
        redirect_to(redirection_url)
      end
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
        format.json { render plain: "deviceStatus({'status':'#{@service_job.status}'})" }
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
          format.html { head :no_content }
        end
      else
        format.html { render plain: 'Вы находитесь на разных подразделениях с устройством. Смените подразделение' }
      end
    end
  end

  def quick_search
    @service_jobs = policy_scope(ServiceJob).quick_search(params[:quick_search])
    respond_to do |format|
      format.js { head(:no_content) if @service_jobs.count > 10 }
    end
  end

  def set_keeper
    @service_job = find_record ServiceJob
    new_keeper_id = @service_job.keeper == current_user ? nil : current_user.id
    @service_job.update_attribute :keeper_id, new_keeper_id
    respond_to(&:js)
  end

  def archive
    @service_job = find_record ServiceJob
    respond_to do |format|
      if @service_job.archive
        ServiceJobs::MakeReview.call(service_job: @service_job, user: current_user)
        format.js
      else
        format.js { render_error @service_job.errors.full_messages }
      end
    end
  end

  private

  def make_review_url
    return unless current_user.able_to?(:request_review)
    time_out = Setting.request_review_time_out(@service_job.department) * 60
    review = Review.create(
      service_job: @service_job,
      user: current_user,
      client: @service_job.client,
      phone: @service_job.client.full_phone_number,
      token: SecureRandom.urlsafe_base64,
      status: :draft
    )
    SendMessageWithReviewUrlJob.set(wait: time_out).perform_later(review.id)
  rescue StandardError => e
    Rails.logger.debug(e.message)
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
    template = action_name.include?('v2') ? 'form_v2' : 'form'
    render template
  end

  def set_job_templates
    @job_templates = Service::JobTemplate.select(:field_name, :content).all.to_a.group_by(&:field_name)
  end

  def generate_qr_link
    case @division
    when "reception"
      @qr_link = generate_svg_qr(new_service_job_photo_url(@service_job, division: "reception"))
    when "in_operation"
      @qr_link = generate_svg_qr(new_service_job_photo_url(@service_job, division: "in_operation"))
    when "completed"
      @qr_link = generate_svg_qr(new_service_job_photo_url(@service_job, division: "completed"))
    end
  end

  def generate_svg_qr(link)
    RQRCode::QRCode.new(link).as_svg(viewbox: true)
  end

  def prepare_check_list_data
    @available_check_lists = available_check_lists_for('ServiceJob')
    @check_list_responses_hash = check_list_responses_hash_for(@service_job, 'ServiceJob')
  end

  def service_job_params
    params.require(:service_job).permit(
      :app_store_pass, :carrier_id, :case_color_id, :claimed_defect, :client_address, :client_comment,
      :client_id, :client_notified, :comment, :completeness, :contact_phone, :department_id,
      :device_condition, :device_group, :device_type_id, :done_at, :email, :estimated_cost_of_repair, :imei,
      :initial_department_id, :is_tray_present, :item_id, :keeper_id, :location_id, :notify_client,
      :replaced, :return_at, :sale_id, :security_code, :serial_number, :status, :tech_notice,
      :ticket_number, :trademark, :type_of_work, :user_id, :substitute_phone_id, :substitute_phone_icloud_connected,
      data_storages: [],
      device_tasks_attributes: %i[id _destroy task_id cost comment user_comment performer_id],
      check_list_responses_attributes: [:id, :check_list_id, responses: {}]
    )
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

  def search_params
    params.require(:search).permit!.to_h
  end

  def notify_params
    # TODO: Сформировать корректный список разрешенных параметров
    params.permit!.to_h
    # params.permit(:id,
    #               device_task: [:id, :cost, :user_comment],
    #               device_note: [:content],
    #               service_job: [:location_id])
  end
end
