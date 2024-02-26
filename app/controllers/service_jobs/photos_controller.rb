module ServiceJobs
  class PhotosController < ApplicationController
    before_action :set_service_job
    before_action :set_photo_container

    def show
      authorize @service_job
      case params[:division]
      when "reception"
        @photos = @photo_container.reception_photos
        @photos_data = @photo_container.reception_photos_meta_data
      when "in_operation"
        @photos = @photo_container.in_operation_photos
        @photos_data = @photo_container.in_operation_photos_meta_data
      when "completed"
        @photos = @photo_container.completed_photos
        @photos_data = @photo_container.completed_photos_meta_data
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
      authorize @service_job, :edit?
      case photos_params[:division]
      when "reception"
        return unless add_photos_to_container("reception")
      when "in_operation"
        return unless add_photos_to_container("in_operation")
      when "completed"
        return unless add_photos_to_container("completed")
      end
      @photo_container.save!
      redirect_to service_job_url(@service_job)
    end

    def destroy
      authorize @service_job
      case params[:division]
      when "reception"
        deleted_photo = @photo_container.reception_photos.delete_at(params[:id].to_i)
        @photo_container.reception_photos_meta_data.delete_at(params[:id].to_i)
      when "in_operation"
        deleted_photo = @photo_container.in_operation_photos.delete_at(params[:id].to_i)
        @photo_container.in_operation_photos_meta_data.delete_at(params[:id].to_i)
      when "completed"
        deleted_photo = @photo_container.completed_photos.delete_at(params[:id].to_i)
        @photo_container.completed_photos_meta_data.delete_at(params[:id].to_i)
      end
      @photo_container.save!
      redirect_to service_job_url(@service_job)
    end

    private

    def add_photos_to_container(division)
      division_photos = @photo_container.send("#{division}_photos")
      division_meta_data = @photo_container.send("#{division}_photos_meta_data")
      existing_photos_count = division_photos.size
      new_photos = photos_params[:photos]
      if existing_photos_count + new_photos.size <= 15
        division_photos += new_photos
        division_meta_data += create_meta_data(new_photos.size)
        @photo_container.send("#{division}_photos=", division_photos)
        @photo_container.send("#{division}_photos_meta_data=", division_meta_data)
        return true
      elsif existing_photos_count == 15
        flash[:alert] = "В данном отделе уже 15 фото."
        redirect_back(fallback_location: service_job_url(@service_job))
        return false
      else
        flash[:alert] = "В данном отделе уже #{existing_photos_count} фото. Можно добавить еще #{15 - existing_photos_count} фото."
        redirect_back(fallback_location: service_job_url(@service_job))
        return false
      end
    end

    def create_meta_data(size)
      meta_data = []
      size.times do |i|
        meta_data << {user: current_user.short_name, date: DateTime.current.strftime("%d.%m.%Y %H:%M")}
      end
      meta_data
    end

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