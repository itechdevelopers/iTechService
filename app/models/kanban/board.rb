class Kanban::Board < ApplicationRecord
  has_many :columns, -> { ordered }, class_name: 'Kanban::Column', dependent: :destroy
  has_and_belongs_to_many :managers,
                          class_name: "User",
                          join_table: :kanban_boards_users,
                          association_foreign_key: :user_id,
                          foreign_key: :kanban_board_id

  validates :name, presence: true, uniqueness: true

  def auto_add_departments
    Department.where(id: auto_add_department_ids)
  end

  def auto_add_department_ids=(ids)
    super(ids.reject(&:blank?).map(&:to_i))
  end

  def initial_column
    columns.ordered.first
  end

  def archived_cards
    Kanban::Card.unscoped
                .joins(:column)
                .where(kanban_columns: {board_id: id})
                .where(archived: true)
  end
end
