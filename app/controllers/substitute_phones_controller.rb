# frozen_string_literal: true

class SubstitutePhonesController < ApplicationController
  skip_after_action :verify_authorized
  respond_to :html

  def index
    @substitute_phones = policy_scope(SubstitutePhone).query(params.to_unsafe_hash.symbolize_keys)

    respond_to do |format|
      format.html { render_cell SubstitutePhone::Cell::Index, model: @substitute_phones }
      format.js
    end
  end

  def show
    @substitute_phone = find_record SubstitutePhone
    render_cell SubstitutePhone::Cell::Show, model: @substitute_phone
  end

  def new
    run SubstitutePhone::Create::Present do
      return render_form
    end
    failed
  end

  def create
    run SubstitutePhone::Create do
      return redirect_to operation_model, notice: operation_message
    end
    render_form
  end

  def edit
    run SubstitutePhone::Update::Present do
      return render_form
    end
    failed
  end

  def update
    run SubstitutePhone::Update do
      return redirect_to_index notice: operation_message
    end
    render_form
  end

  def destroy
    run SubstitutePhone::Destroy do
      return redirect_to substitute_phones_url, notice: t('substitute_phones.destroyed')
    end
    failed
  end

  private

  def render_form
    render_cell SubstitutePhone::Cell::Form
  end

  def substitute_phone_params
    params.require(:substitute_phone)
          .permit(:archived, :condition, :department_id, :item_id, :service_job_id)
  end
end
