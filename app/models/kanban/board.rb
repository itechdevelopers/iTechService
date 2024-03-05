class Kanban::Board < ApplicationRecord
  has_many :columns, -> { ordered }, class_name: 'Kanban::Column', dependent: :destroy
  has_and_belongs_to_many :managers,
                          class_name: "User",
                          join_table: :kanban_boards_users,
                          association_foreign_key: :user_id,
                          foreign_key: :kanban_board_id

  validates :name, presence: true, uniqueness: true

  def initial_column
    columns.ordered.first
  end
end
