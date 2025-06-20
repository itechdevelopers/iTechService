class ElqueueWindowsController < ApplicationController
  before_action :set_elqueue_window, only: %i[show_finish_service take_a_break
                                              return_from_break free_window]

  def select_window
    authorize ElqueueWindow
    current_user.update_column(:need_to_select_window, false)
    @modal = "select_window"
    respond_to do |format|
      format.js { render 'shared/show_modal_form' }
    end
  end

  def show_finish_service
    authorize ElqueueWindow
    @waiting_client = @elqueue_window.waiting_client
    @modal = "finish_service_#{@waiting_client.id}"
    respond_to do |format|
      format.js { render 'shared/show_modal_form' }
    end
  end

  def take_a_break
    authorize ElqueueWindow
    @elqueue_window.set_inactive!
    if current_user.serving_client?
      current_user.set_remember_pause
    else
      current_user.pause!
    end
    respond_to do |format|
      format.js { render 'renew_elqueue_navbar' }
    end
  end

  def return_from_break
    authorize ElqueueWindow
    @elqueue_window.set_active!
    current_user.resume! if current_user.paused?
    respond_to do |format|
      format.js { render 'renew_elqueue_navbar' }
    end
  end

  def free_window
    authorize @elqueue_window
    @elqueue_window.user&.free_window
  end

  private

  def set_elqueue_window
    @elqueue_window = ElqueueWindow.find(params[:id])
  end
end
