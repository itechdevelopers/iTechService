# frozen_string_literal: true
class TelephonyController < ApplicationController
  def show
    authorize :telephony
    response.headers['Cache-Control'] = 'no-store'
    render layout: false
  end
  def ticket
    authorize :telephony
    response.headers['Cache-Control'] = 'no-store'
    render json: { ticket: Telephony::Ticket.issue(current_user), extension: current_user.telephony_extension,
                   gateway: Telephony::Configuration.gateway_origin }
  end
  def caller
    authorize :telephony
    response.headers['Cache-Control'] = 'no-store'
    render json: Telephony::CallerContext.new(current_user, params[:number]).call
  end
end
