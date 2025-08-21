module Service
  class SmsNotificationsController < ApplicationController
    include OperationRunner
    before_action { authorize SMSNotification }
    respond_to :js

    def new
      run SMSNotification::Build do |r|
        r.success &method(:render_new)
        r.failure &method(:failed)
      end
    end

    def create
      run SMSNotification::Create do |r|
        r.success do
          @message = t('service.sms_notification.whatsapp_sent')
          render 'success'
        end

        r.failure do |error|
          @message = t('service.sms_notification.message_not_sent', error: error)
          render 'failure'
        end
      end
    end

    private

    def render_new(sms_notification)
      @content = cell(SMSNotification::Cell::Form, sms_notification, service_job_id: params[:service_job_id]).call
      render 'new'
    end
  end
end
