class DeleteExpiredFaults
  def call
    expiration_date = Date.current.beginning_of_month
    Fault.expireable.where('date < ?', expiration_date).delete_all
  end

  def self.call
    new.call
  end
end