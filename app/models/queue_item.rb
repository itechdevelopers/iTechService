class QueueItem < ApplicationRecord
  belongs_to :electronic_queue
  has_many :queue_tickets, class_name: "WaitingClient", foreign_key: "queue_item_id", dependent: :destroy
  has_ancestry orphan_strategy: :rootify, cache_depth: true

  validates :priority, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 3}

  enum priority: {
    chronological: 0,  # "Хронологическая"
    always_first: 1,   # "Всегда первый"
    always_second: 2,  # "Второй"
    always_third: 3    # "Третий"
  }

  def priority_label
    I18n.t("queue_items.priorities.#{priority}")
  end
end