class ClientPolicy < CommonPolicy
  def create?
    any_manager?(:software, :media, :universal)
  end

  def update?
    any_manager?(:marketing) || able_to?(:edit_clients)
  end

  def destroy?
    any_admin?
  end

  def select?; read?; end

  def find?; read?; end

  def show_caller?; read?; end

  def export?
    superadmin?
  end

  def change_category?
    any_admin?
  end
end
