class Kanban::Card < ApplicationRecord
  scope :ordered, -> { order :position }
  scope :deadline_asc, -> { reorder(deadline: :asc) }
  scope :deadline_desc, -> { reorder(deadline: :desc) }
  scope :classic, -> { ordered }

  belongs_to :author, class_name: 'User'
  belongs_to :column, inverse_of: :cards
  has_many :comments, as: :commentable, dependent: :destroy
  has_and_belongs_to_many :managers,
                          class_name: "User",
                          join_table: :kanban_cards_users,
                          association_foreign_key: :user_id,
                          foreign_key: :kanban_card_id

  mount_uploaders :photos, KanbanPhotoUploader

  validates_presence_of :author, :column, :content

  delegate :presentation, to: :author, prefix: true
  delegate :name, to: :column, prefix: true
  delegate :board, :board_name, to: :column

  acts_as_list scope: :column_id
end
