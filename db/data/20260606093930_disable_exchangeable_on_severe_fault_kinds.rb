# frozen_string_literal: true

class DisableExchangeableOnSevereFaultKinds < ActiveRecord::Migration[5.1]
  # Минусы этих видов нельзя «выкупать» плюсами — слишком серьёзные.
  # Best-effort по имени: если в проде имена записаны иначе, тимлид снимет
  # галочку «Обменять можно» вручную в админке вида минуса.
  SEVERE_NAMES = ['Грубые нарушения', 'Прямой ущерб компании'].freeze

  def up
    FaultKind.where(name: SEVERE_NAMES).update_all(exchangeable: false)
  end

  def down
    FaultKind.where(name: SEVERE_NAMES).update_all(exchangeable: true)
  end
end
