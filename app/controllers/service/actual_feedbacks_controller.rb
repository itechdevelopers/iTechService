module Service
  class ActualFeedbacksController < ApplicationController
    skip_after_action :verify_authorized, only: :index
    respond_to :js

    def index
      feedbacks = FeedbacksQuery.new(policy_scope(Feedback)).actual
      @feedbacks_list = cell(Feedback::Cell::List, feedbacks).call
    end
  end
end
