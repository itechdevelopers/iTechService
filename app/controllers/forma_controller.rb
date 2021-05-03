class FormaController < ApplicationController
  def edit
    authorize :forma
  end

  def update
    authorize :forma

    uploader = FormaUploader.new
    uploader.store!(params[:file])
    setting = Setting.find_by_name('forma_filename')
    setting.update(value: uploader.filename)

    redirect_to forma_path
  end
end