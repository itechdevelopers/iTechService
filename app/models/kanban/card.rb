class Kanban::Card < ApplicationRecord
  scope :ordered, -> { order :position }

  belongs_to :author, class_name: 'User'
  belongs_to :column, inverse_of: :cards
  has_many :comments, as: :commentable, dependent: :destroy

  validates_presence_of :author, :column, :content

  delegate :presentation, to: :author, prefix: true
  delegate :name, to: :column, prefix: true
  delegate :board, :board_name, to: :column

  acts_as_list scope: :column_id
end