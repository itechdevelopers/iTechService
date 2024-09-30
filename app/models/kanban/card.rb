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
  validates :name, presence: true, length: { maximum: 200 }

  delegate :presentation, to: :author, prefix: true
  delegate :name, to: :column, prefix: true
  delegate :board, :board_name, to: :column

  acts_as_list scope: :column_id

  def url
    Rails.application.routes.url_helpers.kanban_card_path(self)
  end

  def notification_recipients
    board.managers
  end

  def notification_message
    "Новый комментарий к канбан карточке: #{content[0..50]}."
  end
end
