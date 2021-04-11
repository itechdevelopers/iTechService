class UserApi < Grape::API
  version 'v1', using: :path

  before { authenticate! }

  desc 'Show user info'
  get 'profile' do
    present current_user
  end

end