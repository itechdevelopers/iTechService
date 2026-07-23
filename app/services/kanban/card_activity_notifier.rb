# frozen_string_literal: true

# Sends personal Telegram DMs about a Kanban card's lifecycle.
#
# Two recipient sets:
#   * board managers  — notified once, when a card is created (they are
#     "responsible on the board");
#   * activity recipients (author + card managers) — notified about ongoing
#     activity (moves, comments) until the card lands in a "done" column.
#
# The acting user is always excluded — you don't get pinged about your own
# action. Delivery goes through NotifyEmployeeJob, which no-ops safely for
# employees who haven't linked Telegram.
module Kanban
  class CardActivityNotifier
    def initialize(card, actor: User.current)
      @card = card
      @actor = actor
    end

    # п.1 — новая карточка на доске → ответственным на доске
    def card_created
      notify(board_manager_recipients, new_card_text)
    end

    # п.2/3 — карточку перенесли между колонками (кроме «Готово»)
    def card_moved(from_column, to_column)
      notify(activity_recipients, moved_text(from_column, to_column))
    end

    # п.2/3 — карточку перенесли в колонку «Готово» (важное сообщение)
    def card_done(to_column)
      notify(activity_recipients, done_text(to_column))
    end

    # п.2/3 — новый комментарий к карточке
    def comment_added(comment)
      notify(activity_recipients, comment_text(comment))
    end

    private

    attr_reader :card, :actor

    def board_manager_recipients
      without_actor(card.board.managers.to_a)
    end

    def activity_recipients
      without_actor([card.author, *card.managers])
    end

    def without_actor(users)
      users.compact.uniq.reject { |user| actor && user.id == actor.id }
    end

    # Runs inside KanbanCardActivityNotificationJob, so deliver synchronously —
    # NotifyEmployee no-ops for employees who haven't linked Telegram.
    def notify(recipients, text)
      recipients.each { |user| NotifyEmployee.call(user: user, text: text) }
    end

    def new_card_text
      <<~MSG.strip
        На доске <b>#{esc(card.board_name)}</b>, где вы ответственный, новая карточка:

        <b>#{esc(card.name)}</b>

        #{link}
      MSG
    end

    def moved_text(from_column, to_column)
      <<~MSG.strip
        Карточка <b>#{esc(card.name)}</b> на доске <b>#{esc(card.board_name)}</b> перемещена:
        #{esc(from_column&.name)} → #{esc(to_column&.name)}

        #{link}
      MSG
    end

    def done_text(to_column)
      <<~MSG.strip
        ✅ Карточка <b>#{esc(card.name)}</b> на доске <b>#{esc(card.board_name)}</b> перенесена в «#{esc(to_column&.name)}».

        #{link}
      MSG
    end

    def comment_text(comment)
      <<~MSG.strip
        💬 Новый комментарий к карточке <b>#{esc(card.name)}</b> на доске <b>#{esc(card.board_name)}</b>:

        #{esc(comment.content)}
        — #{esc(comment.user&.short_name)}

        #{link}
      MSG
    end

    def link
      %(<a href="#{card_url}">Перейти на карточку</a>)
    end

    def card_url
      Rails.application.routes.url_helpers.kanban_card_url(card)
    end

    def esc(text)
      CGI.escapeHTML(text.to_s)
    end
  end
end
