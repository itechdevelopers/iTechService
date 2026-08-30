# frozen_string_literal: true

require 'digest'

# Read-only, service-to-service API for the external iTech AI backend.
class BotApi < Grape::API
  format :json
  default_format :json

  helpers do
    def authenticate_bot!
      expected_token = ENV['AIS_BOT_API_TOKEN'].to_s
      supplied_token = env['HTTP_AUTHORIZATION'].to_s[/\ABearer\s+(.+)\z/i, 1].to_s

      authenticated = expected_token.present? && supplied_token.present? &&
                      ActiveSupport::SecurityUtils.secure_compare(
                        Digest::SHA256.hexdigest(supplied_token),
                        Digest::SHA256.hexdigest(expected_token)
                      )

      bot_error!('UNAUTHORIZED', 'Unauthorized', 401) unless authenticated
    end

    def bot_error!(code, message, status)
      error!({ success: false, error: { code: code, message: message } }, status)
    end

    def participating_department!
      Department.real.participating_in_repair_services.find_by(id: params[:department_id]) ||
        bot_error!('NOT_FOUND', 'Service department not found', 404)
    end

    def repair_service_items(require_service_query: false)
      model_query = params[:model].to_s.strip
      service_query = params[:service].to_s.strip

      if params[:product_id].blank? && model_query.blank?
        bot_error!('INVALID_PARAMETERS', 'product_id or model is required', 400)
      end
      bot_error!('INVALID_PARAMETERS', 'service is required', 400) if require_service_query && service_query.blank?

      department = participating_department!
      query = Bot::RepairServicesQuery.new(
        department: department,
        product_id: params[:product_id],
        model: model_query,
        service: service_query,
        limit: params[:limit]
      )

      query.call.map do |result|
        Bot::RepairServicePresenter.new(
          product: result.product,
          repair_service: result.repair_service,
          department: department,
          price: result.price
        ).as_json
      end
    rescue Bot::RepairServicesQuery::ProductNotFound
      bot_error!('NOT_FOUND', 'Device model not found', 404)
    end
  end

  namespace 'bot/v1' do
    before { authenticate_bot! }

    resource :repair_services do
      desc 'List repair services and branch prices for a device model'
      params do
        requires :department_id, type: Integer
        optional :product_id, type: Integer
        optional :model, type: String
        optional :service, type: String
        optional :limit, type: Integer, values: 1..100, default: 50
      end
      get do
        { success: true, items: repair_service_items }
      end

      desc 'Search a repair service price for a device model'
      params do
        requires :department_id, type: Integer
        optional :product_id, type: Integer
        optional :model, type: String
        requires :service, type: String
        optional :limit, type: Integer, values: 1..100, default: 50
      end
      get :search do
        { success: true, items: repair_service_items(require_service_query: true) }
      end

      route_param :id, type: Integer do
        get do
          department = participating_department!
          service = RepairService.not_archived.includes(:products, :prices, spare_parts: { product: { items: :store_items } }).find(params[:id])
          product = if params[:product_id].present?
                      service.products.merge(Product.devices).find_by(id: params[:product_id])
                    else
                      service.products.merge(Product.devices).first
                    end
          bot_error!('NOT_FOUND', 'Repair service not found', 404) unless product
          { success: true, data: Bot::RepairCatalogPresenter.new(repair_service: service, department: department).as_json }
        end
      end
    end

    resource :repair_catalog do
      params do
        optional :department_id, type: Integer
        optional :product_id, type: Integer
        optional :model, type: String
        optional :limit, type: Integer, values: 1..100, default: 100
      end
      get do
        department = params[:department_id].present? ? participating_department! : nil
        services = Bot::RepairServicesQuery.catalog(model: params[:model], product_id: params[:product_id], limit: params[:limit])
        { success: true, items: services.map { |service| Bot::RepairCatalogPresenter.new(repair_service: service, department: department).as_json } }
      end
    end

    resource :repair_branches do
      params do
        optional :active_only, type: Boolean, default: true
      end
      get do
        # `main_branches` is the existing customer-location scope (used by
        # Client and City); `real` also includes remote/internal departments.
        departments = Department.main_branches
        departments = departments.active if params[:active_only]
        {
          success: true,
          items: departments.map do |department|
            {
              id: department.id,
              name: department.name,
              city: department.city_name,
              repair_participating: department.participates_in_repair_services?
            }
          end
        }
      end
    end

    resource :service_jobs do
      route_param :ticket_number, type: String do
        desc 'Show a client-safe service job status by exact public ticket number'
        get :status do
          service_job = ServiceJob.includes(:location, :repair_status, department: :city)
                                  .find_by(ticket_number: params[:ticket_number])
          bot_error!('NOT_FOUND', 'Service job not found', 404) unless service_job

          { success: true, data: Bot::ServiceJobStatusPresenter.new(service_job).as_json }
        end
      end
    end
  end

  rescue_from Grape::Exceptions::ValidationErrors do |exception|
    error!({
             success: false,
             error: { code: 'INVALID_PARAMETERS', message: exception.message }
           }, 400)
  end

  rescue_from ActiveRecord::RecordNotFound do
    error!({
             success: false,
             error: { code: 'NOT_FOUND', message: 'Resource not found' }
           }, 404)
  end

  rescue_from :all do |exception|
    Rails.logger.error("[BotApi] #{exception.class}: #{exception.message}")
    error!({
             success: false,
             error: { code: 'INTERNAL_ERROR', message: 'Internal server error' }
           }, 500)
  end
end
