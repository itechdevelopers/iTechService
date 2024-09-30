# frozen_string_literal: true

class CommentsController < ApplicationController
  helper_method :sort_column, :sort_direction

  def index
    authorize Comment

    # TODO: refactor
    if (commentable_type = params[:commentable_type]).present? &&
       (commentable_id = params[:commentable_id]).present?
      if commentable_type.constantize.respond_to?(:find)
        @commentable = commentable_type.constantize.find(commentable_id)
        @comments = @commentable.comments
      end
    else
      @comments = if params.key?(:sort) && params.key?(:direction)
                    Comment.order("comments.+#{sort_column} #{sort_direction}")
                  else
                    Comment.newest.page(params[:page])
                  end
      @comments = @comments.page(params[:page])
    end

    respond_to do |format|
      format.html
      format.json { render json: @comments }
      format.js
    end
  end

  def show
    @comment = find_record Comment

    respond_to do |format|
      format.html
      format.json { render json: @comment }
    end
  end

  def new
    @comment = authorize Comment.new

    respond_to do |format|
      format.html
      format.json { render json: @comment }
    end
  end

  def edit
    @comment = find_record Comment
  end

  def create
    @comment = authorize Comment.new(comment_params)
    @comment.user_id = current_user.id

    respond_to do |format|
      if @comment.save
        create_notifications
        format.html { redirect_to @comment, notice: t('comments.created') }
        format.json { render json: @comment, status: :created, location: @comment }
        format.js
      else
        format.html { render action: 'new' }
        format.json { render json: @comment.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @comment = find_record Comment

    respond_to do |format|
      if @comment.update_attributes(comment_params)
        updated_text = comment_params.fetch(:content, @comment.content)
        RecordEdit.create!(editable: @comment, user: current_user, updated_text: updated_text)

        format.html { redirect_to @comment, notice: t('comments.updated') }
        format.json { head :no_content }
        format.js
      else
        format.html { render action: 'edit' }
        format.json { render json: @comment.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @comment = find_record Comment
    @comment.destroy

    respond_to do |format|
      format.html { redirect_to comments_url }
      format.json { head :no_content }
    end
  end

  private

  def create_notifications
    if @notifications&.any?
      update_notifications
    elsif @comment.commentable.respond_to?(:notification_recipients)
      message = @comment.commentable.notification_message
      @comment.commentable.notification_recipients.each do |recipient|
        notification = Notification.create(user_id: recipient.id,
                                           message: message,
                                           url: @comment.commentable.url,
                                           referenceable: @comment.commentable)
        UserNotificationChannel.broadcast_to(notification.user, notification) unless notification.errors.any?
      end

    end
  end

  def update_notifications
    @notifications.each do |notification|
      if @comment.commentable.respond_to?(:url)
        notification.update(url: @comment.commentable.url, referenceable: @comment, message: @comment.content[0..50])
        UserNotificationChannel.broadcast_to(notification.user, notification) unless notification.errors.any?
      end
    end
  end

  def sort_column
    Comment.column_names.include?(params[:sort]) ? params[:sort] : ''
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : ''
  end

  def comment_params
    params.require(:comment)
          .permit(:commentable_id, :commentable_type, :content, :user_id)
  end
end
