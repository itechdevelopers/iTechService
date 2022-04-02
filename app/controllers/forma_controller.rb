class FormaController < ApplicationController
  def show
    skip_authorization
    uploader = FormaUploader.new
    send_file uploader.full_path, disposition: 'inline'
  rescue ActionController::MissingFile
    render file: 'public/404.html', layout: false, status: :not_found
  end

  def new
    authorize :forma
  end

  def create
    authorize :forma

    uploader = FormaUploader.new
    uploader.store!(params[:file])

    redirect_to forma_path
  end
end
