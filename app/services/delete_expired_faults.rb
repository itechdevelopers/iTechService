class DeleteExpiredFaults
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def call
    if user.present?
      delete_faults_of user
    else
      User.all.each do |user|
        delete_faults_of user
      end
    end
  end

  def self.call(user=nil)
    new(user).call
  end

  private

  def delete_faults_of(user)
    expiration_date = Date.current.end_of_month
    user.faults.expireable.where('date < ?', expiration_date).delete_all
  end
end