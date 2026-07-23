class Kanban::Card < ApplicationRecord
  include Auditable

  default_scope { where(archived: false) }
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

  audited
  has_associated_audits

  after_update_commit :notify_column_change

  def url
    Rails.application.routes.url_helpers.kanban_card_path(self)
  end

  def notification_recipients
    board.managers
  end

  def notification_message
    "Новый комментарий к канбан карточке: #{content[0..50]}."
  end

  def archive!
    update!(archived: true)
  end

  def unarchive!
    update!(archived: false)
  end

  private

  # Fires on any update; only column moves are relevant. Covers both the
  # drag-drop path (CardsController#update_card_columns) and the edit form —
  # both funnel through a single `update(column_id:)`.
  def notify_column_change
    return unless previous_changes.key?('column_id')

    old_id, new_id = previous_changes['column_id']
    event = Kanban::Column.find_by(id: new_id)&.done? ? 'card_done' : 'card_moved'
    KanbanCardActivityNotificationJob.perform_later(
      event, id, User.current&.id, from_column_id: old_id, to_column_id: new_id
    )
  end
end
