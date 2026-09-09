# frozen_string_literal: true

module ServiceJobs
  class VideosController < ApplicationController
    before_action :set_service_job
    before_action :set_video

    def show
      authorize @service_job
      @modal = "video-#{@video.id}"
      respond_to do |format|
        format.js { render 'shared/show_modal_form' }
      end
    end

    # The <video> tag points here rather than at the signed storage URL: a
    # signature expires, and a clip left paused for longer than that would
    # answer a seek with 403 — a working file looking broken. This action holds
    # a permanent address and mints a fresh signature per request instead.
    def stream
      authorize @service_job, :show?
      redirect_to @video.file.file.authenticated_url(expires_in: 10.minutes)
    end

    private

    def set_service_job
      @service_job = ServiceJob.find(params[:service_job_id])
    end

    def set_video
      @video = @service_job.videos.find(params[:id])
    end
  end
end
