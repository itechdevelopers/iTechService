class ReportsBoard < ApplicationRecord
  has_many :report_columns

  after_create :create_default_column

  private
  
  def create_default_column
    report_columns.create(name: "Общая")
  end
end
