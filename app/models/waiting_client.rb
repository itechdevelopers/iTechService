class WaitingClient < ApplicationRecord
  belongs_to :queue_item
  belongs_to :client, optional: true
  belongs_to :elqueue_window, optional: true

  before_create :set_initial_attributes
  after_create :broadcast_create, :trigger_electronic_queue_move

  validates :status, inclusion: { in: ["waiting", "in_service", "completed", "did_not_come"] }

  default_scope { order(position: :asc) }

  scope :waiting, -> { where(status: "waiting") }
  scope :in_service, -> { where(status: "in_service") }
  scope :in_queue, ->(electronic_queue) { joins(:queue_item).where(queue_items: { electronic_queue_id: electronic_queue.id }) }

  enum priority: {
    chronological: 0,
    always_first: 1,
    always_second: 2,
    always_third: 3
  }

  attr_accessor :country_code

  class << self
    def add_to_queue(waiting_client)
      @@waiting_clients = in_queue(waiting_client.electronic_queue).waiting.where.not(position: nil)
      case waiting_client.priority
      when "always_first"
        max_position = max_position_with_priority(["always_first"])
        move_all_with_greater_position(max_position)
        waiting_client.position = max_position + 1
      when "chronological"
        max_position = max_position_with_priority(["chronological"])
        if max_position == 0
          max_position = max_position_with_priority(["always_first"])
        elsif @@waiting_clients.where(position: max_position + 2).first&.priority == "always_third"
          max_position = max_position + 2
        elsif @@waiting_clients.where(position: max_position + 1).first&.priority == "always_second"
          max_position = max_position + 1
        end
        move_all_with_greater_position(max_position)
        waiting_client.position = max_position + 1
      when "always_second"
        max_position = max_position_with_priority(["always_first", "always_second", "chronological"])
        max_position = max_position + 1 if @@waiting_clients.where(position: max_position + 1).first&.priority == "always_third"
        move_all_with_greater_position(max_position)
        waiting_client.position = max_position + 1
      when "always_third"
        max_position = max_position_with_priority(["always_first", "always_third", "chronological"])
        max_position = max_position + 1 if @@waiting_clients.where(position: max_position + 1).first&.priority == "always_second"
        move_all_with_greater_position(max_position)
        waiting_client.position = max_position + 1
      end
    end

    def max_position_with_priority(priorities)
      @@waiting_clients.where(priority: priorities).maximum(:position) || 0
    end

    def move_all_with_greater_position(position)
      @@waiting_clients.where("waiting_clients.position > ?", position).update_all("position = position + 1")
    end

    def realign_positions(electronic_queue)
      @@waiting_clients = in_queue(electronic_queue).waiting.where.not(position: nil)
      @@waiting_clients.each_with_index do |waiting_client, index|
        new_position = index + 1
        waiting_client.update(position: new_position) if waiting_client.position != new_position
      end
    end
  end

  def start_service(window)
    self.update(status: "in_service",
                elqueue_window: window,
                ticket_called_at: Time.zone.now,
                position: nil)
    self.class.realign_positions(queue_item.electronic_queue)
    # ActionCable.server.broadcast "electronic_queue_#{queue_item.electronic_queue_id}_channel", action: "start_service", waiting_client: self
  end

  def complete_service(did_not_come = false)
    self.update(status: did_not_come ? "did_not_come" : "completed",
                ticket_served_at: Time.zone.now,
                elqueue_window: nil)
    queue_item.electronic_queue.move
    self.class.realign_positions(queue_item.electronic_queue)
    # ActionCable.server.broadcast "electronic_queue_#{queue_item.electronic_queue_id}_channel", action: "complete_service", waiting_client: self
  end

  def electronic_queue
    queue_item.electronic_queue
  end

  private

  def trigger_electronic_queue_move
    queue_item.electronic_queue.move
  end

  def broadcast_create
    # ActionCable.server.broadcast "electronic_queue_#{queue_item.electronic_queue_id}_channel", action: "create", waiting_client: self
  end

  def set_initial_attributes
    self.ticket_number ||= evaluate_ticket_number
    self.status ||= "waiting"
    self.priority = queue_item.priority
    self.client ||= Client.find_by(phone_number: phone_number)
    self.ticket_issued_at ||= Time.zone.now
    self.class.add_to_queue(self)
  end

  def evaluate_ticket_number
    number = queue_item.increment_ticket_number!
    ticket_number_prefix + number.to_s
  end

  def ticket_number_prefix
    queue_item.ticket_abbreviation ? queue_item.ticket_abbreviation : ""
  end
end