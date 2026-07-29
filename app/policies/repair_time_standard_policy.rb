class RepairTimeStandardPolicy < CommonPolicy
  # Аналитическая страница-справочник — доступна менеджерам и технарям.
  def index?
    any_manager?(:technician)
  end

  def show?
    index?
  end
end
