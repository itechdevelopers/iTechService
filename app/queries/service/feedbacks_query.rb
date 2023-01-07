# frozen_string_literal: true

module Service
  class FeedbacksQuery
    def initialize(scope = Feedback.all)
      @scope = scope
    end

    def actual
      @scope.includes(service_job: :client).actual.where(clients: {disable_deadline_notifications: [nil, false]})
    end
  end
end
