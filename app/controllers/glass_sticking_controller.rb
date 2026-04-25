class GlassStickingController < ApplicationController
  before_action :authenticate_user!

  def show
    authorize :glass_sticking
  end

  def recipients
    authorize :glass_sticking, :recipients?
    @recipients = []
    respond_to(&:js)
  end

  def notify
    authorize :glass_sticking, :notify?
    head :ok
  end
end
