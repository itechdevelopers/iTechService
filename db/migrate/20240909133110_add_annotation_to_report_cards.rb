class AddAnnotationToReportCards < ActiveRecord::Migration[5.1]
  def change
    add_column :report_cards, :annotation, :text, default: ''
  end
end
