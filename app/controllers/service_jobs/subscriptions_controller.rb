module ServiceJobs
  class SubscriptionsController < ApplicationController
    skip_after_action :verify_authorized

    def create
      @service_job = find_service_job
      
      # Check if user can subscribe (validate subscription limit)
      if current_user.subscribed_service_jobs.count >= 10
        respond_to do |format|
          format.js { render_error I18n.t('activerecord.errors.models.user.subscription_limit_reached') }
        end
      elsif @service_job.subscribers.include?(current_user)
        # Already subscribed, just refresh
        respond_to do |format|
          format.js { render :refresh }
        end
      else
        # Add subscription
        @service_job.subscribers << current_user
        respond_to do |format|
          format.js { render :refresh }
        end
      end
    rescue ActiveRecord::RecordInvalid => e
      respond_to do |format|
        format.js { render_error e.message }
      end
    end

    def destroy
      @service_job = find_service_job
      @service_job.subscribers.delete(current_user)
      respond_to do |format|
        format.js { render :refresh }
      end
    end

    private

    def find_service_job
      policy_scope(ServiceJob).find(params[:service_job_id])
    end
  end
end