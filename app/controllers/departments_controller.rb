# frozen_string_literal: true

class DepartmentsController < ApplicationController
  def index
    authorize Department
    @departments = Department.all
    respond_to do |format|
      format.html
    end
  end

  def show
    @department = find_record Department
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
    @department = find_record Department
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
    @department = find_record Department
    respond_to do |format|
      if @department.update_attributes(department_params)
        format.html { redirect_to @department, notice: t('departments.updated') }
      else
        format.html { render 'form' }
      end
    end
  end

  def destroy
    @department = find_record Department
    @department.destroy
    respond_to do |format|
      format.html { redirect_to departments_url }
    end
  end

  def department_params
    params.require(:department)
          .permit(:address, :brand_id, :city_id, :code, :contact_phone, :ip_network, :name, :printer, :role, :schedule, :short_name, :url)
  end
end
