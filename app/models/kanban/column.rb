class Kanban::Column < ApplicationRecord
  scope :ordered, -> { order :position }
  scope :in_board, ->(board) { where board_id: board }

  belongs_to :board, class_name: 'Kanban::Board'
  has_many :cards, -> { ordered }, class_name: 'Kanban::Card', dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :board_id }

  delegate :name, to: :board, prefix: true

  acts_as_list scope: :board_id
end
