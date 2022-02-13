# frozen_string_literal: true

class DeviceNotesController < ApplicationController
  def index
    authorize DeviceNote
    @service_job = find_service_job
    @device_notes = @service_job.device_notes.newest_first
    @device_note = @service_job.device_notes.build(user_id: current_user.id)
    respond_to do |format|
      format.js { render 'shared/show_modal_form' }
    end
  end

  def new
    @service_job = find_service_job
    @device_note = authorize @service_job.device_notes.build(user_id: current_user.id)
    respond_to do |format|
      format.js
    end
  end

  def create
    @service_job = find_service_job
    @device_note = authorize @service_job.device_notes.build(device_note_params)
    @device_note.user = current_user

    respond_to do |format|
      if @device_note.save
        format.js
        permitted_params = params.permit!.to_h
        Service::DeviceSubscribersNotificationJob.perform_later(@service_job.id, current_user.id, permitted_params)
      else
        format.js { head :unprocessable_entity }
      end
    end
  end

  private

  def find_service_job
    policy_scope(ServiceJob).find(params[:service_job_id])
  end

  def device_note_params
    params.require(:device_note).permit(:content, :service_job_id, :user_id)
  end
end
