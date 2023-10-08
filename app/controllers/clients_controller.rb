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
