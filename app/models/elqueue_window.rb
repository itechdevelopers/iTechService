class ElqueueWindow < ApplicationRecord
  belongs_to :electronic_queue
  has_one :waiting_client, class_name: "WaitingClient", dependent: :nullify
  has_one :user, dependent: :nullify

  validates :window_number, presence: true

  scope :free, -> { left_joins(:waiting_client).where(waiting_clients: { id: nil }) }
  scope :not_chosen, -> { left_joins(:user).where(users: { id: nil }) }
  scope :active, -> { where(is_active: true) }
  scope :active_free, -> { active.free }

  def serving_client?
    waiting_client.present?
  end

  def next_waiting_client
    waiting_clients = WaitingClient.in_queue(electronic_queue)
                                   .waiting
                                   .where.not(position: nil)

    waiting_client_only_for_this_window = waiting_clients.with_attached_window(window_number).to_a

    waiting_clients_for_window = waiting_clients.without_attached_window
                                                .to_a
                                                .select { |wc| wc.queue_item.windows_array.include?(window_number) }

    wcs = waiting_clients_for_window.concat(waiting_client_only_for_this_window)
    return wcs.min_by(&:position) if wcs.any?
    waiting_clients.without_attached_window.order(:position).first
  end

  def set_active!
    update!(is_active: true)
    trigger_electronic_queue_move
  end

  def set_inactive!
    update!(is_active: false)
  end

  private

  def trigger_electronic_queue_move
    electronic_queue.move
  end
end