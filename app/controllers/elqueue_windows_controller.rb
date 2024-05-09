class ElqueueWindowsController < ApplicationController
  def select_window
    authorize ElqueueWindow
    current_user.update_column(:need_to_select_window, false)
    @modal = "select_window"
    respond_to do |format|
      format.js { render 'shared/show_modal_form' }
    end
  end
end