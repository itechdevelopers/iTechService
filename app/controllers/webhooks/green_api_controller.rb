module Webhooks
  class GreenApiController < ApplicationController
    skip_before_action :verify_authenticity_token
    skip_before_action :authenticate_user!
    skip_after_action :verify_authorized

    def status
      # Log incoming webhook for debugging
      Rails.logger.info "[GreenAPI Webhook] Received: #{params.to_json}"

      # Validate instance ID matches our configuration
      unless valid_instance?
        Rails.logger.warn "[GreenAPI Webhook] Invalid instance ID: #{params.dig(:instanceData, :idInstance)}"
        return render json: { status: 'unauthorized' }, status: :unauthorized
      end

      # Find SMS notification by message_id
      sms_notification = Service::SMSNotification.find_by(message_id: params[:idMessage])

      unless sms_notification
        Rails.logger.info "[GreenAPI Webhook] SMS notification not found for message: #{params[:idMessage]}"
        # Return success to avoid webhook retries for messages we don't track
        return render json: { status: 'ok', message: 'message not found' }, status: :ok
      end

      # Update status and description if failed
      update_params = { whatsapp_status: params[:status] }
      update_params[:whatsapp_status_description] = params[:description] if params[:description].present?

      if sms_notification.update(update_params)
        Rails.logger.info "[GreenAPI Webhook] Updated SMS notification #{sms_notification.id} status to: #{params[:status]}"
      else
        Rails.logger.error "[GreenAPI Webhook] Failed to update SMS notification #{sms_notification.id}: #{sms_notification.errors.full_messages.join(', ')}"
      end

      render json: { status: 'ok' }, status: :ok
    rescue => e
      Rails.logger.error "[GreenAPI Webhook] Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      # Return success to avoid webhook retries on our errors
      render json: { status: 'error', message: e.message }, status: :ok
    end

    private

    def valid_instance?
      # Check if instance ID from webhook matches our configured instance
      instance_id = params.dig(:instanceData, :idInstance).to_s
      configured_id = ENV['GREEN_API_INSTANCE_ID'].to_s

      # Log for debugging (without exposing full IDs in logs)
      if instance_id.present? && configured_id.present?
        Rails.logger.info "[GreenAPI Webhook] Instance validation: received=#{instance_id[0..4]}..., configured=#{configured_id[0..4]}..."
      end

      instance_id.present? && configured_id.present? && instance_id == configured_id
    end
  end
end