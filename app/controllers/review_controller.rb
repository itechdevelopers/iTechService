class ReviewController < ActionController::Base
  before_action :set_review

  # GET /review/<token>
  def edit
    if @review && (@review.reviewed_at.nil? || @review.reviewed_at > 10.minutes.ago)
      MarkReviewViewedJob.perform_later(@review.id)
    else
      redirect_to '/review'
    end
  end

  # PATCH /review/<token>
  def update
    @review.update review_params.merge(reviewed_at: DateTime.current, status: :reviewed)
    redirect_to '/review'
  end

  # GET /review
  def welcome
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_review
      @review = Review.find_by(token: params[:token])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def review_params
      params.require(:review).permit(:value, :content)
    end
end
