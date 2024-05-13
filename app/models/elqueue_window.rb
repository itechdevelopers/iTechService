class ElqueueWindow < ApplicationRecord
  belongs_to :electronic_queue
  has_one :waiting_client, class_name: "WaitingClient", dependent: :nullify
  has_one :user, dependent: :nullify

  validates :window_number, presence: true

  scope :free, -> { left_joins(:waiting_client).where(waiting_clients: { id: nil }) }
  scope :active, -> { where(is_active: true) }
  scope :active_free, -> { active.free }

  def serving_client?
    waiting_client.present?
  end

  def next_waiting_client
    waiting_clients = WaitingClient.in_queue(electronic_queue)
                                   .waiting
                                   .where.not(position: nil)

    waiting_clients_for_window = waiting_clients.to_a
                                                .select { |wc| wc.queue_item.windows_array.include?(window_number) }
    return waiting_clients_for_window.min_by(&:position) if waiting_clients_for_window.any?
    waiting_clients.order(:position).first
  end

  def set_active!
    update!(is_active: true)
  end

  def set_inactive!
    update!(is_active: false)
  end
end