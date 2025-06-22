class Users::SessionsController < Devise::SessionsController
  layout 'auth'
  respond_to :html, :json
  skip_after_action :verify_authorized
# before_action :configure_sign_in_params, only: [:create]

  # GET /resource/sign_in
  # def new
  #   super
  # end

  # POST /resource/sign_in
  def create
    super do |user|
      if user.working_electronic_queue?
        user.need_to_select_window = true
        user.save
      end

      user.resume!
      user.unset_remember_pause

      if (location = after_sign_in_path_for(user))
        respond_with resource, location: location
        return
      end

      if user.department_autochangeable?
        return redirect_to edit_user_department_path unless autochange_department(user)
      end
    end
  end

  def sign_in_by_card
    respond_to do |format|
      if (user = User.find_by_card_number(params[:card_number])).present?
        if params[:current_user].to_i == user.id
          sign_in :user, user, bypass: true
        else
          sign_in :user, user
        end

        location = after_sign_in_path_for(user)
        if user.department_autochangeable?
          location = edit_user_department_path unless autochange_department(user)
        end

        format.json { respond_with user, location: location }
      else
        format.json { respond_with({error: 'user_not_found'}, location: new_user_session_url) }
      end
    end
  end

  def sign_in_technical
    tech_user = User.find_by(username: "tech_user")
    location = after_sign_in_path_for(tech_user)

    if tech_user.valid_password?(params[:user][:password])
      sign_in :user, tech_user
      respond_with tech_user, location: location
    else
      render :new_technical_login
    end
  end

  def new_technical_login; end

  # DELETE /resource/sign_out
  def destroy
    current_user.need_to_select_window = false if current_user.need_to_select_window

    current_user.deactivate_elqueue_window
    current_user.resume!
    current_user.unset_remember_pause
    current_user.save

    super
  end

  protected

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_sign_in_params
  #   devise_parameter_sanitizer.permit(:sign_in, keys: [:attribute])
  # end

  def after_sign_in_path_for(resource)
    stored_location = session.delete(:user_return_to)
    stored_location || super
  end

  def autochange_department(user)
    departments = if (user.superadmin? || user.able_to?(:access_all_departments))
                     Department.all
                   else
                     Department.in_city(user.city)
                   end
    if departments.count == 1
      change_user_department user, departments.first
      return true
    end

    return true if user.department.ip_network.blank? || user.department.ip_network == user.current_sign_in_ip

    new_department = Department.find_by(ip_network: user.current_sign_in_ip)
    return false if new_department.nil?

    change_user_department user, new_department
  end
end
