class WaitingClient < ApplicationRecord
  belongs_to :queue_item
  belongs_to :client, optional: true
  belongs_to :elqueue_window, optional: true

  has_many :elqueue_ticket_movements

  before_create :set_initial_attributes
  after_create :set_move_ticket_job
  after_create :trigger_electronic_queue_move

  validates :status, inclusion: { in: ['waiting', 'in_service', 'completed', 'did_not_come'] }

  default_scope { order(position: :asc) }

  scope :with_attached_window, lambda { |win_num|
    where(attached_window: win_num)
  }
  scope :without_attached_window, -> { where(attached_window: nil) }
  scope :waiting, -> { where(status: 'waiting') }
  scope :in_service, -> { where(status: 'in_service') }
  scope :finalized, -> { where(status: %w[completed did_not_come]) }
  scope :in_queue, lambda { |electronic_queue|
    joins(:queue_item).where(queue_items: { electronic_queue_id: electronic_queue.id })
  }
  scope :today, lambda {
    where(ticket_issued_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day)
  }
  scope :waiting_in_queue, ->(electronic_queue) { in_queue(electronic_queue).waiting.where.not(position: nil) }

  enum priority: {
    chronological: 0,
    always_first: 1,
    always_second: 2,
    always_third: 3,
    moved_by_timing: 4
  }

  attr_accessor :country_code

  def self.max_position_with_priority(priorities, queue)
    waiting_in_queue(queue).where(priority: priorities).maximum(:position) || 0
  end

  def self.move_all_with_greater_position(position, queue)
    waiting_in_queue(queue).where('waiting_clients.position > ?', position).update_all('position = position + 1')
  end

  def self.realign_positions(queue)
    waiting_in_queue(queue).each_with_index do |waiting_client, index|
      new_position = index + 1
      waiting_client.update(position: new_position) if waiting_client.position != new_position
    end
  end

  class << self
    def add_to_queue(waiting_client)
      queue = waiting_client.electronic_queue
      position = nil
      case waiting_client.priority
      when 'moved_by_timing'
        max_position = max_position_with_priority(['moved_by_timing', 'always_first'], queue)
        move_all_with_greater_position(max_position, queue)
        position = max_position + 1
      when 'always_first'
        max_position = max_position_with_priority(['always_first'], queue)
        move_all_with_greater_position(max_position, queue)
        position = max_position + 1
      when 'chronological'
        max_position = max_position_with_priority(['chronological'], queue)
        if max_position == 0
          max_position = max_position_with_priority(['always_first'], queue)
        elsif waiting_in_queue(queue).where(position: max_position + 2).first&.priority == 'always_third'
          max_position += 2
        elsif waiting_in_queue(queue).where(position: max_position + 1).first&.priority == 'always_second'
          max_position += 1
        end
        move_all_with_greater_position(max_position, queue)
        position = max_position + 1
      when 'always_second'
        max_position = max_position_with_priority(%w[always_first always_second chronological], queue)
        max_position += 1 if waiting_in_queue(queue).where(position: max_position + 1).first&.priority == 'always_third'
        move_all_with_greater_position(max_position, queue)
        position = max_position + 1
      when 'always_third'
        max_position = max_position_with_priority(%w[always_first always_third chronological], queue)
        if waiting_in_queue(queue).where(position: max_position + 1).first&.priority == 'always_second'
          max_position += 1
        end
        move_all_with_greater_position(max_position, queue)
        position = max_position + 1
      end

      waiting_client.update!(position: position) if position
    end
  end

  def start_service(window)
    old_pos = position
    update!(status: 'in_service',
            elqueue_window: window,
            ticket_called_at: Time.zone.now,
            position: nil)
    self.class.realign_positions(queue_item.electronic_queue)
    broadcast_start_service

    elqueue_ticket_movements.create(type: 'ElqueueTicketMovement::Called',
                                    old_position: old_pos,
                                    elqueue_window: window,
                                    user: window.user,
                                    electronic_queue: electronic_queue,
                                    queue_state: electronic_queue.queue_state)
  end

  def complete_service(did_not_come = false)
    update!(status: did_not_come ? 'did_not_come' : 'completed',
            ticket_served_at: Time.zone.now,
            elqueue_window: nil)
    trigger_electronic_queue_move
    broadcast_complete
  end

  def complete_automatically
    update!(status: 'did_not_come',
            completed_automatically: true,
            ticket_served_at: Time.zone.now,
            elqueue_window: nil)
    broadcast_complete
  end

  def complete_waiting_automatically
    time_completed = Time.zone.now
    update!(status: 'did_not_come',
            completed_automatically: true,
            ticket_called_at: time_completed,
            ticket_served_at: time_completed,
            position: nil)
  end

  def return_to_queue(user)
    return unless %w[completed did_not_come].include? status

    update!(status: 'waiting')
    self.class.add_to_queue(self)
    elqueue_ticket_movements.create(type: 'ElqueueTicketMovement::RequeuedCompleted',
                                    new_position: position,
                                    electronic_queue: electronic_queue,
                                    queue_state: electronic_queue.queue_state,
                                    user: user,
                                    priority: priority_value)
    trigger_electronic_queue_move
  end

  def electronic_queue
    @electronic_queue ||= queue_item.electronic_queue
  end

  # Двигаем талон автоматически по времени
  def move_to_beginning
    old_position = position
    update!(position: nil, priority: 'moved_by_timing')
    self.class.add_to_queue(self)
    self.class.realign_positions(electronic_queue)

    elqueue_ticket_movements.create(type: 'ElqueueTicketMovement::TimeoutMoved',
                                    old_position: old_position,
                                    new_position: position,
                                    electronic_queue: electronic_queue,
                                    queue_state: electronic_queue.queue_state,
                                    priority: priority_value)
  end

  # Метод для талона в очереди
  def assign_window(window_number)
    update!(attached_window: window_number)
    trigger_electronic_queue_move
  end

  # Метод вызывается в момент, когда талон уже обслуживается в окне
  def reassign_window(window_number, user)
    old_window = elqueue_window
    update!(elqueue_window: nil,
            ticket_called_at: nil,
            priority: 'always_first',
            status: 'waiting',
            attached_window: window_number)
    broadcast_complete
    self.class.add_to_queue(self)

    elqueue_ticket_movements.create(type: 'ElqueueTicketMovement::Requeued',
                                    new_position: position,
                                    electronic_queue: electronic_queue,
                                    queue_state: electronic_queue.queue_state,
                                    user: user,
                                    elqueue_window: old_window,
                                    priority: priority_value)
    trigger_electronic_queue_move
  end

  def queue_item_ancestors
    queue_item.ancestors_and_self_titles
  end

  def priority_value
    priority_before_type_cast
  end

  private

  def set_move_ticket_job
    return unless (wait_time = queue_item.max_wait_time).present?

    MoveWaitingClientJob.set(wait: wait_time.minutes).perform_later(self.id)
  end

  def trigger_electronic_queue_move
    electronic_queue.move
  end

  def broadcast_start_service
    waiting_client_data = {
      ticket_number: ticket_number,
      queue_item_ancestors: queue_item_ancestors
    }
    ElectronicQueueChannel.broadcast_to(electronic_queue,
                                        action: 'start_service',
                                        waiting_client: waiting_client_data,
                                        window: elqueue_window.window_number)
  end

  def broadcast_complete
    waiting_client_data = {
      ticket_number: ticket_number
    }
    ElectronicQueueChannel.broadcast_to(electronic_queue,
                                        action: 'complete_service',
                                        waiting_client: waiting_client_data)
  end

  def set_initial_attributes
    self.ticket_number ||= evaluate_ticket_number
    self.status ||= 'waiting'
    self.priority = queue_item.priority
    # self.client ||= Client.find_by(phone_number: phone_number)
    self.ticket_issued_at ||= Time.zone.now
  end

  def evaluate_ticket_number
    number = queue_item.increment_ticket_number!
    ticket_number_prefix + number.to_s
  end

  def ticket_number_prefix
    queue_item.ticket_abbreviation || ''
  end
end
