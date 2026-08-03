class Kanban::MoneyEntry < ApplicationRecord
  belongs_to :card, class_name: 'Kanban::Card', inverse_of: :money_entries

  validates :reason, presence: true
  validates :amount, presence: true, numericality: { only_integer: true, greater_than: 0 }
end
