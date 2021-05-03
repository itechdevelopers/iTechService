class ReviewsController < ApplicationController
  include Sortable
  # include ServiceJobsHelper
  # helper_method :sort_column, :sort_direction
  # skip_before_action :authenticate_user!, :set_current_user, only: :check_status
  skip_after_action :verify_authorized, only: %i[index]

  before_action :set_review, only: [:show, :edit, :update, :destroy]

  # GET /reviews
  # GET /reviews.json
  def index
    @reviews = policy_scope(Review)
    @reviews = ReviewFilter.call(collection: @reviews, **filter_params).collection
    @reviews = paginate(@reviews)
    respond_to do |format|
      format.html
      format.json { render json: @reviews }
      format.js { render 'shared/index', locals: { resource_table_id: 'reviews_table' } }
    end
  end

  # GET /reviews/1
  # GET /reviews/1.json
  def show
  end

  # GET /reviews/new
  def new
    @review = Review.new
  end

  # GET /reviews/1/edit
  def edit
  end

  # POST /reviews
  # POST /reviews.json
  def create
    @review = Review.new(review_params)

    respond_to do |format|
      if @review.save
        format.html { redirect_to @review, notice: 'Review was successfully created.' }
        format.json { render :show, status: :created, location: @review }
      else
        format.html { render :new }
        format.json { render json: @review.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /reviews/1
  # PATCH/PUT /reviews/1.json
  def update
    respond_to do |format|
      if @review.update(review_params)
        format.html { redirect_to @review, notice: 'Review was successfully updated.' }
        format.json { render :show, status: :ok, location: @review }
      else
        format.html { render :edit }
        format.json { render json: @review.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /reviews/1
  # DELETE /reviews/1.json
  def destroy
    @review.destroy
    respond_to do |format|
      format.html { redirect_to reviews_url, notice: 'Review was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_review
      @review = Review.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
  #   def review_params
  #     params.require(:review).permit(:client_id, :service_job_id, :value, :content, :token)
  #   end
  #
  # def sort_column
  #   Review.column_names.include?(params[:sort]) ? params[:sort] : ''
  # end
end
