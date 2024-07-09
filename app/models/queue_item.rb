class QueueItem < ApplicationRecord
  belongs_to :electronic_queue
  has_many :queue_tickets, class_name: 'WaitingClient', foreign_key: 'queue_item_id', dependent: :destroy
  has_ancestry orphan_strategy: :rootify, cache_depth: true

  validates :priority, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 3}

  enum priority: {
    chronological: 0,  # "Хронологическая"
    always_first: 1,   # "Всегда первый"
    always_second: 2,  # "Второй"
    always_third: 3    # "Третий"
  }

  def ancestors_and_self_titles
    ancestor_titles = self.class.ancestors_of(self).order(:ancestry_depth).pluck(:title)
    ancestor_titles << title
    ancestor_titles.join(' - ')
  end

  def priority_label
    I18n.t("queue_items.priorities.#{priority}")
  end

  def increment_ticket_number!
    new_number = last_ticket_number? ? last_ticket_number + 1 : 1
    update!(last_ticket_number: new_number)
    new_number
  end

  def windows_array
    numbers = windows.scan(/\d+/).map(&:to_i)
    max_window_number = electronic_queue.windows_count
    numbers.select { |number| number <= max_window_number }
  end
end