# frozen_string_literal: true

# Standalone «Я сломал» form: the same report a technician files from the task
# modal, but filed for someone else — the ticket and the employee are picked by
# hand. The ticket comes first because the spare part picker and the stock
# validation both hang off the branch the job belongs to.
class BreakageReportsController < ApplicationController
  def new
    authorize BreakageReport
    find_service_job
    @breakage_report = BreakageReport.new(service_job: @service_job, user: current_user) if @service_job.present?
  end

  def create
    @breakage_report = BreakageReport.new(breakage_report_params)
    authorize @breakage_report
    @service_job = @breakage_report.service_job

    if @breakage_report.save
      redirect_to service_job_path(@service_job), notice: t('.success', ticket: @service_job.ticket_number)
    else
      render :new
    end
  end

  private

  def find_service_job
    ticket = params[:ticket_number].to_s.strip
    return if ticket.blank?

    @service_job = ServiceJob.find_by_ticket_number(ticket)

    if @service_job.blank?
      @ticket_error = t('.not_found', ticket: ticket)
    else
      @existing_report = @service_job.breakage_reports.first
    end
  end

  def breakage_report_params
    params.require(:breakage_report).permit(:service_job_id, :user_id, :circumstances, :resolution, :item_id)
  end
end
