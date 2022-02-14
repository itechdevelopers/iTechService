class CasePicturesController < ApplicationController
  def index
    skip_authorization
    respond_to do |format|
      format.html
    end
  end

  def new

  end

  def create
    skip_authorization
    if (file = params[:file]).present?
      filepath = file.path
      pdf = CasePicturePdf.new filepath, params
      send_data pdf.render, filename: 'case_picture', type: 'application/pdf', disposition: 'inline'
    else
      render nothing: true
    end
  end
end
