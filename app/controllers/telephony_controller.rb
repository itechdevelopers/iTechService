# frozen_string_literal: true
class TelephonyController < ApplicationController
  def show
    authorize :telephony
    response.headers['Cache-Control'] = 'no-store'
    render layout: false
  end
  def workspace
    authorize :telephony
    response.headers['Cache-Control'] = 'no-store'
    @workspace_path = Telephony::WorkspacePath.valid?(params[:path]) ? params[:path] : root_path
    render layout: false
  end

  def ticket
    authorize :telephony
    response.headers['Cache-Control'] = 'no-store'
    render json: { ticket: Telephony::Ticket.issue(current_user), extension: current_user.telephony_extension,
                   gateway: Telephony::Configuration.gateway_origin }
  end
  def directory
    authorize :telephony
    response.headers['Cache-Control'] = 'no-store'
    render json: { entries: PhoneLabel.order(:group_name, :label, :phone_number).map { |entry|
      { number: entry.phone_number, label: entry.label, group: entry.group_name }
    } }
  end
  def caller
    authorize :telephony
    response.headers['Cache-Control'] = 'no-store'
    render json: Telephony::CallerContext.new(current_user, params[:number]).call
  end
end
