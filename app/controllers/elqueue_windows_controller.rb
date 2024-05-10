class ElqueueWindowsController < ApplicationController
  before_action :set_elqueue_window, only: %i[show_finish_service]

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
    @modal = "finish_service_#{@elqueue_window.id}"
    respond_to do |format|
      format.js { render 'shared/show_modal_form' }
    end
  end

  private

  def set_elqueue_window
    @elqueue_window = ElqueueWindow.find(params[:id])
  end
end