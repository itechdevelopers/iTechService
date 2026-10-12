class TelephonyDirectoryController < ApplicationController
  def index
    authorize :telephony_directory, :index?
    load_entries
    @entry = params[:edit].present? ? PhoneLabel.find(params[:edit]) : PhoneLabel.new
  end

  def create
    authorize :telephony_directory, :manage?
    save_entry(PhoneLabel.new)
  end

  def update
    authorize :telephony_directory, :manage?
    save_entry(PhoneLabel.find(params[:id]))
  end

  def destroy
    authorize :telephony_directory, :manage?
    PhoneLabel.find(params[:id]).destroy!
    redirect_to telephony_directory_index_path, notice: 'Номер удалён из справочника.'
  end

  private

  def load_entries
    @entries = PhoneLabel.includes(:department, :user).order(:label).page(params[:page]).per(100)
    @departments = Department.order(:name)
    @employees = User.active.order(:surname, :name)
  end

  def save_entry(entry)
    @entry = entry
    attrs = params.require(:phone_label).permit(:phone_number, :label, :group_name, :department_id, :user_id)
    number = Telephony::Number.dialable(attrs[:phone_number])
    @entry.assign_attributes(attrs.merge(phone_number: number || attrs[:phone_number]))
    if number && @entry.save
      redirect_to telephony_directory_index_path, notice: 'Справочник обновлён.'
    else
      @entry.errors.add(:phone_number, 'Укажите внутренний номер или российский телефон с 7.') unless number
      load_entries
      render :index, status: :unprocessable_entity
    end
  end
end
