module ServiceJobs
  class PhotosController < ApplicationController
    skip_before_action :authenticate_user!, only: %i[new]
    before_action :authenticate_by_token, only: %i[new]
    before_action :set_service_job
    before_action :set_photo_container
    def new
      authorize @service_job
      render layout: false
    end

    def edit

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

    def update
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

    def authenticate_by_token
      token = Token.where("expires_at > ?", Time.now).find_by(token: params[:token])
      if token && token.user
        sign_in(:user, token.user)
      else
        redirect_to root_path, status: :unauthorized, alert: "Вы не аторизованы для просмотра этой страницы. Пожалуйста, авторизуйтесь."
      end
    end
  end
end