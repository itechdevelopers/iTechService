class Kanban::Board < ApplicationRecord
  has_many :columns, -> { ordered }, class_name: 'Kanban::Column', dependent: :destroy

  validates :name, presence: true, uniqueness: true

  def initial_column
    columns.ordered.first
  end
end
