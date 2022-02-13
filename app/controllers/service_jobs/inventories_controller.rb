module ServiceJobs
  class InventoriesController < ApplicationController
    before_action :authorize
    before_action :set_location

    def new
      @service_jobs = local_service_jobs

      respond_to do |format|
        format.html
      end
    end

    def show
      @service_jobs = local_service_jobs.where(id: LostDevice.pluck(:service_job_id))

      respond_to do |format|
        format.html
      end
    end

    def create
      found_job_ids = inventory_params[:found_job_ids]
      lost_job_ids = inventory_params[:job_ids].split - found_job_ids

      lost_job_ids.each do |job_id|
        LostDevice.find_or_create_by(service_job_id: job_id)
      end

      LostDevice.where(service_job_id: found_job_ids).delete_all
      @service_jobs = ServiceJob.where(id: lost_job_ids).order_by_product_name
      render :new
    end

    private

    def inventory_params
      params[:inventory]
    end

    def authorize
      super ServiceJob, :inventory?
    end

    def local_service_jobs
      ServiceJob.includes(:location).where(location: @location).order_by_product_name
    end

    def set_location
      @location = if params.key?(:location_id)
                    Location.find(action_params[:location_id])
                  else
                    Location.done.find_by(department: Department.current)
                  end
    end
  end
end
