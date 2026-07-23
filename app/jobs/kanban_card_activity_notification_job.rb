# frozen_string_literal: true

# Off-request delivery of Kanban card DMs. Building the absolute card URL needs
# `routes.default_url_options[:host]` (production-only), so this runs async to
# keep host/URL failures out of the request cycle — mirroring
# SendKanbanTelegramNotificationJob.
class KanbanCardActivityNotificationJob < ApplicationJob
  queue_as :default

  def perform(event, card_id, actor_id, opts = {})
    card = Kanban::Card.unscoped.find_by(id: card_id)
    return unless card

    opts = opts.symbolize_keys
    actor = User.find_by(id: actor_id)
    notifier = Kanban::CardActivityNotifier.new(card, actor: actor)

    case event.to_s
    when 'card_created'
      notifier.card_created
    when 'card_moved'
      notifier.card_moved(column(opts[:from_column_id]), column(opts[:to_column_id]))
    when 'card_done'
      notifier.card_done(column(opts[:to_column_id]))
    when 'comment_added'
      comment = Comment.find_by(id: opts[:comment_id])
      notifier.comment_added(comment) if comment
    end
  end

  private

  def column(id)
    id && Kanban::Column.find_by(id: id)
  end
end
