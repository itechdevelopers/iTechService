module ServiceJobs
  class PhotosController < ApplicationController
    before_action :set_service_job
    before_action :set_photo_container

    def show
      authorize @service_job
      case params[:division]
      when "reception"
        @photos = @photo_container.reception_photos
      when "in_operation"
        @photos = @photo_container.in_operation_photos
      when "completed"
        @photos = @photo_container.completed_photos
      end
      @chosen_photo_id = params[:id].to_i
      @modal = "photos-#{params[:division]}-#{@chosen_photo_id}"
      respond_to do |format|
        format.js { render "shared/show_modal_form" }
      end
    end

    def new
      authorize @service_job
      render layout: false
    end

    def create
      authorize @service_job
      case photos_params[:division]
      when "reception"
        @photo_container.reception_photos += photos_params[:photos]
      when "in_operation"
        @photo_container.in_operation_photos += photos_params[:photos]
      when "completed"
        @photo_container.completed_photos += photos_params[:photos]
      end
      @photo_container.save!
      redirect_to service_job_url(@service_job)
    end

    def destroy
      authorize @service_job
      case params[:division]
      when "reception"
        deleted_photo = @photo_container.reception_photos.delete_at(params[:id].to_i)
      when "in_operation"
        deleted_photo = @photo_container.in_operation_photos.delete_at(params[:id].to_i)
      when "completed"
        deleted_photo = @photo_container.completed_photos.delete_at(params[:id].to_i)
      end
      File.delete(deleted_photo.path)
      @photo_container.save!
      redirect_to service_job_url(@service_job)
    end

    private

    def set_service_job
      @service_job = ServiceJob.find(params[:service_job_id])
    end

    def set_photo_container
      if @service_job.photo_container.present?
        @photo_container = @service_job.photo_container
      else
        @photo_container = PhotoContainer.create
        @service_job.photo_container = @photo_container
        @service_job.save!
      end
    end

    def photos_params
      params.require(:photo_container).permit(:division, photos: [])
    end
  end
end