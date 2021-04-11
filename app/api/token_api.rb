class TokenApi < Grape::API
  version 'v1', using: :path

  desc 'Sings in user'
  params do
    requires :username
    requires :password
  end
  post 'signin' do
    username = params[:username]
    password = params[:password]

    if (user = User.find_first_by_auth_conditions auth_token: username.downcase).present?

      user.update_authentication_token

      if user.valid_password? password
        {token: user.authentication_token}.merge(user.as_json)
      else
        error!({message: "Invalid password."}, 401)
      end
    else
      error!({message: "Invalid username or password."}, 401)
    end
  end

  desc 'Sings out user and updates authentication token'
  delete 'signout' do
    authenticate!
    current_user.update_authentication_token
    {success: 'signed_out'}
  end
end
