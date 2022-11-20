class MarkExpiredFaults
  def call
    expiration_date = Date.current.beginning_of_month
    Fault.expireable.active.where('date < ?', expiration_date).update_all(expired: true)
  end

  def self.call
    new.call
  end
end
