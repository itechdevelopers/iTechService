class ElqueueWindow < ApplicationRecord
  belongs_to :electronic_queue
  has_one :waiting_client, class_name: 'WaitingClient', dependent: :nullify
  has_one :user, dependent: :nullify

  validates :window_number, presence: true

  scope :free, -> { left_joins(:waiting_client).where(waiting_clients: { id: nil }) }
  scope :not_chosen, -> { left_joins(:user).where(users: { id: nil }) }
  scope :chosen, -> { left_joins(:user).where.not(users: { id: nil }) }
  scope :active, -> { where(is_active: true) }
  scope :active_free, -> { active.free }

  def serving_client?
    waiting_client.present?
  end

  def next_waiting_client
    active_windows = electronic_queue.elqueue_windows.active_free.pluck(:window_number)
    waiting_clients = WaitingClient
                      .waiting_in_queue(electronic_queue)
                      .preload(:queue_item)
                      .where(
                        <<~SQL,
                          waiting_clients.attached_window = :window_number OR 
                          (waiting_clients.attached_window IS NULL AND queue_items.windows @> :window_array) OR 
                          (waiting_clients.attached_window IS NULL AND 
                           NOT (queue_items.windows && :active_windows_array) AND 
                           queue_items.redirect_windows @> :window_array)
                        SQL
                          {
                            window_number: window_number,
                            window_array: "{#{window_number}}",
                            active_windows_array: "{#{active_windows.join(',')}}"
                          }
                      )
                      .order(:position)
                      .first
    # waiting_clients = WaitingClient
    #                   .waiting_in_queue(electronic_queue)
    #                   .includes(:queue_item)
    #
    # wcs_only_for_this_win = waiting_clients.with_attached_window(window_number).to_a
    #
    # wcs_for_win = waiting_clients
    #               .without_attached_window
    #               .to_a
    #               .select { |wc| wc.queue_item.windows.include?(window_number) }
    #
    # wcs_for_redirect = waiting_clients.without_attached_window
    #                                   .to_a
    #                                   .select do |wc|
    #   (wc.queue_item.windows & active_windows).any? &&
    #     wc.queue_item.redirect_windows.include?(window_number)
    # end
    #
    # wcs = wcs_for_win.union(wcs_only_for_this_win, wcs_for_redirect)
    # wcs.min_by(&:position) if wcs.any?
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
