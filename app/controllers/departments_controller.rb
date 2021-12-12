# frozen_string_literal: true

class DepartmentsController < ApplicationController
  before_action :load_and_authorize_record, only: [:show, :edit, :update, :destroy]

  def index
    authorize Department
    @departments = Department.unscoped.all
    respond_to do |format|
      format.html
    end
  end

  def show
    respond_to do |format|
      format.html
    end
  end

  def new
    @department = authorize Department.new
    respond_to do |format|
      format.html { render 'form' }
    end
  end

  def edit
    respond_to do |format|
      format.html { render 'form' }
    end
  end

  def create
    @department = authorize Department.new(department_params)
    respond_to do |format|
      if @department.save
        format.html { redirect_to @department, notice: t('departments.created') }
      else
        format.html { render 'form' }
      end
    end
  end

  def update
    respond_to do |format|
      if @department.update_attributes(department_params)
        format.html { redirect_to @department, notice: t('departments.updated') }
      else
        format.html { render 'form' }
      end
    end
  end

  def destroy
    @department.destroy
    respond_to do |format|
      format.html { redirect_to departments_url }
    end
  end

  private

  def load_and_authorize_record
    @department = Department.unscoped.find(params[:id])
    authorize @department
  end

  def department_params
    params.require(:department)
          .permit(:address, :brand_id, :city_id, :code, :contact_phone, :ip_network, :name, :printer, :role, :schedule, :short_name, :url, :archive)
  end
end
