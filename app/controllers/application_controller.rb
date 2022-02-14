class ApplicationController < ActionController::Base
  include Pundit
  include ApplicationHelper
  include FilterSortPagination
  protect_from_forgery
  before_action :authenticate_user!
  before_action :set_current_user
  before_action :store_location, except: [:create, :update, :destroy]
  after_action :verify_authorized
  around_action :set_time_zone
  rescue_from Pundit::NotAuthorizedError, with: :not_authorized
  respond_to :html
  helper_method :can?, :current_department, :current_city

  protected

  def current_city
    current_department.city
  end

  def current_department
    current_user.department
  end

  def can?(action, object)
    policy(object).public_send("#{action}?")
  end

  def run(operation, params=self.params, *dependencies)
    result = operation.(
      _run_params(params),
        *_run_runtime_options(*dependencies)
    )

    @contract = result["contract.default"]
    @form = result["contract.default"]
    # @form  = Trailblazer::Rails::Form.new(@contract, result["model"].class)
    @model = result["model"]
    @_result = result

    unless @model.nil?
      model_variable_name = action_name == 'index' ? @model.model_name.collection : @model.model_name.element
      model_variable_name.gsub!('/', '_')
      instance_variable_set "@#{model_variable_name}", @model
    end

    yield(result) if result.success? && block_given?

    result
  end

  def render_cell(cell_class, model: nil, **options)
    model ||= @model
    # options[:layout] = Shared::Cell::Layout unless options.key? :layout
    # options[:contract] = @form unless @form.nil?
    options[:contract] = @contract unless @contract.nil?
    content = cell(cell_class, model, options).call

    if request.xhr?
      render js: "document.getElementById('remote_container').innerHTML = '#{content}'"
    else
      render html: content, layout: true
    end
  end

  private

  def set_time_zone
    if user_signed_in?
      Time.use_zone(current_user.time_zone) { yield }
    else
      yield
    end
  end

  def change_user_department(user, new_department)
    user.department = new_department
    if user.location.present?
      new_location = Location.find_by(department: new_department, code: user.location.code)
      user.location = new_location if new_location.present?
    end
    user.save
  end

  def set_current_user
    User.current = current_user
  end

  def params!(params)
    params.merge current_user: current_user
  end

  def find_record(klass)
    authorize klass.find_by(id: params[:id])
  end

  def not_authorized(error)
    resource_name = error.record.respond_to?(:model_name) ? error.record.model_name.to_s : error.record.to_s
    message = "Доступ запрещён! [#{error.query} #{resource_name}]"
    if request.xhr?
      render js: "App.Notification.show('#{message}', 'alert');"
    else
      flash[:alert] = message
      redirect_to request.referrer || root_path
    end
  end

  def _run_options(options)
    options.merge 'current_user' => current_user
  end

  def failed(message = nil)
    message ||= operation_message
    if request.xhr?
      render_error message
    else
      flash.alert = message
      redirect_to request.referrer || root_path
    end
  end

  def operation_model
    result['model']
  end

  def operation_contract
    result['contract.default']
  end

  def operation_message
    result['result.message']
  end

  def operation_failed?
    result.failure?
  end

  def redirect_to_index(response_status={})
    redirect_to({action: :index}, response_status)
  end

  # def render_object_errors(object)
  #   render_error object.errors.full_messages.to_sentence
  # end

  def render_error(text)
    render_notification text, 'alert'
  end

  def render_notification(text, type='info')
    render js: "alert('#{text}');"
    # render js: "App.Notification.show('#{text}', '#{type}');"
  end

  # TODO: Переопределить в каждом контроллере и выпилить отсюда
  def search_params
    params.to_unsafe_h.deep_symbolize_keys
  end
end
