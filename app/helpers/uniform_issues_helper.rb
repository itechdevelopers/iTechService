# frozen_string_literal: true

module UniformIssuesHelper
  def uniform_recipients_collection
    User.active.staff.includes(:location, :department).order(:surname, :name)
  end
end
