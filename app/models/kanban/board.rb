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

  # "Look & feel" columns copied when `copy_design` is on. Kept as a single list
  # so adding a design field means editing one place. `background_image` is a
  # plain string column on master (no CarrierWave mount here yet), so it is
  # copied as a scalar like the rest.
  DESIGN_ATTRS = %w[background background_image open_background_color card_font_color
                    card_font_size open_card_font_size card_white_background].freeze

  # Creates a fresh board with the given name, always replicating the column
  # skeleton. What else comes along is toggled by the flags:
  #   copy_cards       — card name + content (author = the person copying)
  #   copy_design      — DESIGN_ATTRS (colors, fonts, background)
  #   copy_responsible — board managers, plus each card's managers when cards
  #                      are copied too; fired users (not User.active) are
  #                      silently dropped
  # Comments, positions, deadlines, photos and access (allowed_user_ids) are
  # never copied. Runs in a transaction so a failure leaves no half-built board.
  # On validation failure (usually a blank or duplicate name) the returned board
  # carries the errors and is not persisted.
  def duplicate_structure(new_name, author:, copy_cards: true, copy_design: false, copy_responsible: false)
    new_board = Kanban::Board.new(name: new_name)
    new_board.assign_attributes(attributes.slice(*DESIGN_ATTRS)) if copy_design
    begin
      transaction do
        new_board.save!
        new_board.managers = managers.merge(User.active) if copy_responsible
        columns.ordered.each do |column|
          new_column = new_board.columns.create!(name: column.name)
          next unless copy_cards

          column.cards.ordered.each do |card|
            new_card = new_column.cards.create!(name: card.name, content: card.content, author: author)
            new_card.managers = card.managers.merge(User.active) if copy_responsible
          end
        end
      end
    rescue ActiveRecord::RecordInvalid => e
      new_board.errors.add(:base, e.message) if new_board.errors.empty?
    end
    new_board
  end
end
