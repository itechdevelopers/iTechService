class RepairAttentionMarkersController < ApplicationController
  skip_before_action :authenticate_user!, :set_current_user, only: :dismiss
  skip_after_action :verify_authorized, only: %i[dismiss start_repair]

  def dismiss
    marker = RepairAttentionMarker.find_by!(dismiss_token: params[:token])
    marker.dismiss!
    render plain: 'Уведомление закрыто.'
  end

  def start_repair
    unless user_signed_in?
      flash[:notice] = t('repair_attention.sign_in_then_click_again',
                         default: 'Войдите в АИС и кликните ссылку из Telegram снова.')
      redirect_to new_user_session_path
      return
    end

    marker = RepairAttentionMarker.find_by!(start_token: params[:token])

    if current_user.id != marker.user_id
      flash[:alert] = t('repair_attention.wrong_user',
                       target_user: marker.user.full_name)
      redirect_to service_job_path(marker.service_job)
      return
    end

    marker.mark_started!(current_user)
    apply_repair_status_change(marker)

    redirect_to service_job_path(marker.service_job)
  end

  private

  def apply_repair_status_change(marker)
    service_job = marker.service_job
    return unless service_job.repair_status&.waiting?

    in_progress = RepairStatus.by_code(RepairStatus::IN_PROGRESS)
    active = ServiceJob.active_in_progress_for(current_user)
                       .where.not(id: service_job.id).first

    if active
      paused = RepairStatus.by_code(RepairStatus::PAUSED)
      urgent = RepairPauseReason.find_by(code: RepairPauseReason::URGENT_REPAIR)
      ServiceJob.transaction do
        active.change_repair_status!(paused, user: current_user,
                                     pause_reason: urgent,
                                     displaced_by: service_job)
        service_job.change_repair_status!(in_progress, user: current_user,
                                          changed_at: marker.viewed_at)
      end
      flash[:alert] = t('repair_attention.auto_displaced',
                       new_ticket: service_job.ticket_number,
                       paused_ticket: active.ticket_number)
    else
      service_job.change_repair_status!(in_progress, user: current_user,
                                        changed_at: marker.viewed_at)
    end
  end
end
