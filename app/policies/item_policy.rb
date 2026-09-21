class ItemPolicy < CommonPolicy
  def autocomplete?; read?; end

  def select?; read?; end

  def check_status?; read?; end

  def check_1c_status?; read?; end

  def check_1c_status_by_sn?; read?; end

  def manage?; any_manager?; end

  # Карточку устройства заводит любой сотрудник: она нужна в приёмке, в запросах
  # на разблокировку и в других формах с полем `as: :device`, а найти устройство
  # в базе или в 1С удаётся не всегда. Из формы приходят только product_id и
  # features — складских остатков (store_items) создание карточки не касается.
  # Правка и удаление карточки остаются под modify?/manage?.
  def create?; true; end

  def modify?
    any_manager?(:software, :universal)
  end

  def remains_in_store?
    any_manager?(:software, :universal)
  end
end
