class Kanban::Board < ApplicationRecord
  mount_uploader :background_image, KanbanBackgroundUploader

  scope :active, -> { where(archived: false) }
  scope :archived, -> { where(archived: true) }

  has_many :columns, -> { ordered }, class_name: 'Kanban::Column', dependent: :destroy
  belongs_to :telegram_chat, optional: true
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

  def archive!
    update!(archived: true)
  end

  def unarchive!
    update!(archived: false)
  end

  # Creates a fresh board with the given name replicating only the structure —
  # columns and cards (name + content). Comments, positions, deadlines, photos,
  # managers and access are intentionally not copied: the copy is a blank
  # template meant to be re-assigned from scratch. Runs in a transaction so a
  # failure anywhere leaves no half-built board. On validation failure (most
  # likely a blank or duplicate name) the returned board carries the errors and
  # is not persisted.
  def duplicate_structure(new_name, author:)
    new_board = Kanban::Board.new(name: new_name)
    begin
      transaction do
        new_board.save!
        columns.ordered.each do |column|
          new_column = new_board.columns.create!(name: column.name)
          column.cards.ordered.each do |card|
            new_column.cards.create!(name: card.name, content: card.content, author: author)
          end
        end
      end
    rescue ActiveRecord::RecordInvalid => e
      new_board.errors.add(:base, e.message) if new_board.errors.empty?
    end
    new_board
  end
end
