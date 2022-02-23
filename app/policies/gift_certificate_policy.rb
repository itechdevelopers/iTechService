class GiftCertificatePolicy < BasePolicy
  def manage?
    any_manager?(:software, :universal)
  end

  def issue?
    same_department? && manage?
  end

  def activate?
    same_department? && manage?
  end

  def scan?
    same_department? && manage?
  end

  def find?
    same_department? && manage?
  end

  def history?; read?; end
end
