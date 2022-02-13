module CommonTestHelper
  ActiveRecord::Migration.check_pending!
  include FactoryBot::Syntax::Methods

  def current_user
    @current_user ||= create :user
  end

  def current_admin
    @current_admin ||= create :admin
  end

  # def teardown
  #   super
  #   FileUtils.rm_rf Dir["#{Rails.root}/spec/test_files/"]
  # end
end