# frozen_string_literal: true

# Токен инстанса даёт полный доступ к аккаунту мессенджера компании: читать
# всю переписку и писать от её имени. Поэтому только суперадмин.
class GreenApiInstancePolicy < ApplicationPolicy
  def index?
    superadmin?
  end

  def update?
    superadmin?
  end
end
