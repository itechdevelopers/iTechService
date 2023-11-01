# frozen_string_literal: true

class DeviceNotesController < ApplicationController
  before_action :find_service_job, only: %i[index new create]
  before_action :find_device_note, only: %i[update]

  def index
    authorize DeviceNote
    @device_notes = @service_job.device_notes.oldest_first
    @device_note = @service_job.device_notes.build(user_id: current_user.id)
    @modal = "device-notes-#{@service_job.id}"
    respond_to do |format|
      format.js { render 'shared/show_modal_form' }
    end
  end

  def new
    @device_note = authorize @service_job.device_notes.build(user_id: current_user.id)
    respond_to do |format|
      format.js
    end
  end

  def create
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

  def update
    authorize @device_note
    record_edit = RecordEdit.find_or_create_by!(editable: @device_note, user: current_user)
    record_edit.touch
    respond_to do |format|
      if @device_note.update(device_note_params)
        format.js
      else
        format.js { head :unprocessable_entity }
      end
    end
  end

  private

  def find_service_job
    @service_job = policy_scope(ServiceJob).find(params[:service_job_id])
  end

  def find_device_note
    @device_note = DeviceNote.find(params[:id])
  end

  def device_note_params
    params.require(:device_note).permit(:content, :service_job_id, :user_id)
  end
end
