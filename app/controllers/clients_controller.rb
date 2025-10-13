# frozen_string_literal: true

class ClientsController < ApplicationController
  skip_after_action :verify_authorized, only: %i[check_phone_number questionnaire autocomplete select]

  def index
    authorize Client
    @clients = policy_scope(Client).search(search_params).id_asc.page(params[:page])
    if params[:search] == 'true'
      params[:table_name] = 'table_small'
      params[:form_name] = 'search_form'
    end
    respond_to do |format|
      format.html
      format.json { render json: @clients }
      format.js { render(params[:search] == 'true' ? 'shared/show_modal_form' : 'shared/index') }
    end
  end

  def show
    @client = find_record(Client.includes(:sale_items, :orders, :free_jobs, :quick_orders, :trade_in_devices,
                                          service_jobs: :device_tasks))

    respond_to do |format|
      format.html
      format.json { render json: @client }
    end
  end

  def show_caller
    authorize Client
    number = params[:id][-10, 10]
    clients = policy_scope(Client).search(phone_number: number)

    if clients.one?
      @client = clients.includes(:sale_items, :orders, :free_jobs, :quick_orders, :trade_in_devices,
                                 service_jobs: :device_tasks).first
      render 'show'
    else
      params[:client_q] = params[:id][/\d+/]
      @clients = clients.id_asc.page(params[:page])
      render 'index'
    end
  end

  def history
    @client = find_record Client

    # Fetch ALL client's history first to find characteristic IDs
    all_client_records = @client.history_records

    # Fetch current characteristic's history (if exists)
    current_characteristic_records = @client.client_characteristic&.history_records || []

    # Find all client_characteristic_ids this client has ever had
    # by looking at the history of client_characteristic_id changes
    characteristic_id_changes = all_client_records.where(column_name: 'client_characteristic_id')
    all_characteristic_ids = characteristic_id_changes.map { |r| [r.old_value, r.new_value] }.flatten.compact.uniq

    # Add the current characteristic id if it exists
    all_characteristic_ids << @client.client_characteristic_id if @client.client_characteristic_id

    # Fetch ALL history records for any ClientCharacteristic this client has ever had
    # Include both records with matching IDs and orphaned records (object_id: nil)
    # Also filter out empty value records
    all_characteristic_records = if all_characteristic_ids.any?
      HistoryRecord.where(object_type: 'ClientCharacteristic')
                   .where('object_id IN (?) OR object_id IS NULL', all_characteristic_ids.map(&:to_i))
                   .where.not("(old_value IS NULL OR old_value = '') AND (new_value IS NULL OR new_value = '')")
    else
      # Even if no IDs found, still get orphaned ClientCharacteristic records
      HistoryRecord.where(object_type: 'ClientCharacteristic', object_id: nil)
                   .where.not("(old_value IS NULL OR old_value = '') AND (new_value IS NULL OR new_value = '')")
    end

    # Filter out client_characteristic_id changes and empty value records from client records
    # Empty records are where both old and new values are blank (nil or empty string)
    client_records_filtered = all_client_records
      .where.not(column_name: 'client_characteristic_id')
      .where.not("(old_value IS NULL OR old_value = '') AND (new_value IS NULL OR new_value = '')")

    # Merge all records and sort by newest first
    @records = (client_records_filtered + all_characteristic_records.to_a).uniq.sort_by(&:created_at).reverse

    render 'shared/show_history'
  end

  def new
    @client = authorize Client.new
    @client.build_client_characteristic

    respond_to do |format|
      format.html { render 'form' }
      format.json { render json: @client }
      format.js { render params[:form] == 'modal' ? 'shared/show_modal_form' : 'show_form' }
    end
  end

  def edit
    @client = find_record Client
    @client.build_client_characteristic if @client.client_characteristic.nil?

    respond_to do |format|
      format.html { render 'form' }
      format.js { render params[:form] == 'modal' ? 'shared/show_modal_form' : 'show_form' }
    end
  end

  def create
    @client = authorize Client.new(client_params)
    @client.department = current_department unless able_to?(:set_new_client_department)

    respond_to do |format|
      if @client.save
        format.html { redirect_to @client, notice: t('clients.created') }
        format.js { render params[:form] == 'modal' ? 'select' : 'saved' }
        format.json { render json: @client, status: :created, location: @client }
      else
        format.html { render 'form' }
        format.js { render params[:form] == 'modal' ? 'shared/show_modal_form' : 'show_form' }
        format.json { render json: @client.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @client = find_record Client
    respond_to do |format|
      if @client.update_attributes(client_params)
        format.html { redirect_to @client, notice: t('clients.updated') }
        format.json { head :no_content }
        format.js { render params[:form] == 'modal' ? 'select' : 'saved' }
      else
        format.html { render 'form' }
        format.js { render params[:form] == 'modal' ? 'shared/show_modal_form' : 'show_form' }
        format.json { render json: @client.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @client = find_record Client
    @client.destroy
    respond_to do |format|
      format.html { redirect_to clients_url }
      format.json { head :no_content }
    end
  end

  def check_phone_number
    number = params[:number]
    @number = PhoneTools.convert_phone number
    respond_to do |format|
      format.js
    end
  end

  def questionnaire
    pdf = QuestionnairePdf.new view_context, params[:client]
    send_data pdf.render, filename: 'anketa.pdf', type: 'application/pdf', disposition: 'inline'
  end

  def autocomplete
    @clients = policy_scope(Client).search(search_params).limit(10)
  end

  def select
    @client = find_record(Client.includes(:devices))

    respond_to do |format|
      format.js
    end
  end

  def find
    @client = authorize policy_scope(Client).find_by_card_number(params[:id])

    respond_to do |format|
      format.js { render 'select' }
    end
  end

  def export
    authorize Client

    respond_to do |format|
      format.html
      format.vcf do
        file = ExportClients.call(params[:city_id])
        send_file file, filename: 'clients.vcf', type: 'application/vcf', disposition: 'inline'
      end
    end
  end

  private

  def client_params
    params.require(:client).permit(
      :name, :surname, :patronymic, :birthday, :email, :phone_number, :full_phone_number, :phone_number_checked,
      :card_number, :admin_info, :comment, :contact_phone, :category, :city, :disable_deadline_notifications,
      client_characteristic_attributes: %i[id _destroy client_category_id comment],
      comments_attributes: %i[content commentable_id commentable_type]
    )
  end

  def search_params
    params.permit(:client_q, :client, :phone_number)
  end
end
