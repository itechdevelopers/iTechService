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
    marker.mark_started!(current_user)
    redirect_to service_job_path(marker.service_job)
  end
end
