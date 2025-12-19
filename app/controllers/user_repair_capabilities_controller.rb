# frozen_string_literal: true

class UserRepairCapabilitiesController < ApplicationController
  before_action :set_user
  before_action :set_capability, only: :destroy

  def create
    authorize UserRepairCapability

    repair_service_ids = capability_params[:repair_service_ids]&.reject(&:blank?) || []
    comment = capability_params[:comment]

    @errors = []
    @created_count = 0

    repair_service_ids.each do |repair_service_id|
      capability = @user.user_repair_capabilities.build(
        repair_service_id: repair_service_id,
        comment: comment
      )
      if capability.save
        @created_count += 1
      else
        @errors << capability.errors.full_messages
      end
    end

    respond_to do |format|
      if @created_count.positive?
        format.js { render :create }
      else
        @error_message = @errors.flatten.uniq.join(', ')
        format.js { render :error }
      end
    end
  end

  def destroy
    authorize @capability

    respond_to do |format|
      if @capability.destroy
        format.js { render :destroy }
      else
        format.js { render :error }
      end
    end
  end

  private

  def set_user
    @user = User.find(params[:user_id])
  end

  def set_capability
    @capability = @user.user_repair_capabilities.find(params[:id])
  end

  def capability_params
    params.require(:user_repair_capability).permit(:comment, repair_service_ids: [])
  end
end
