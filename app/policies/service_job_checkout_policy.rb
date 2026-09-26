# frozen_string_literal: true

class ServiceJobCheckoutPolicy < ApplicationPolicy
  # Машинный токен 1С: сообщать об оплате и об отмене может только он.
  def update_from_one_c?
    has_role?(:api)
  end

  def index?
    superadmin? || able_to?(:manage_one_c_checkouts)
  end

  def confirm?
    index?
  end

  def resolve_parts?
    index?
  end

  def read_from_one_c?
    update_from_one_c? || read?
  end
end
