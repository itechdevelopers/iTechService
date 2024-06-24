# frozen_string_literal: true

class AddElqueueTicketsReport < ActiveRecord::Migration[5.1]
  def up
    rb = ReportsBoard.find_by(name: 'Default')
    rcol = rb.report_columns.first
    pos = rcol.last_card_position + 1
    ReportCard.create(content: 'elqueue_tickets', report_column_id: rcol.id, position: pos)
  end

  def down
    ReportCard.find_by(content: 'elqueue_tickets').destroy!
  end
end
