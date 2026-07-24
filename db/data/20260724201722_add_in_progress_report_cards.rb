# frozen_string_literal: true

class AddInProgressReportCards < ActiveRecord::Migration[5.1]
  CONTENTS = %w[repair_works_duration technicians_in_progress_timeline].freeze

  def up
    column = target_column
    return unless column

    base = column.last_card_position
    CONTENTS.each_with_index do |content, index|
      ReportCard.find_or_create_by!(content: content) do |card|
        card.report_column = column
        card.position = base + index + 1
      end
    end
  end

  def down
    ReportCard.where(content: CONTENTS).destroy_all
  end

  private

  # Колонка с остальными отчётами по технарям (та же, где карточка technicians_jobs).
  def target_column
    anchor = ReportCard.find_by(content: 'technicians_jobs')
    return anchor.report_column if anchor

    ReportsBoard.find_by(name: 'Default')&.report_columns&.order(:id)&.first
  end
end
