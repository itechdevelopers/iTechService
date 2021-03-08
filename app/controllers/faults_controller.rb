# frozen_string_literal: true

class FaultsController < ApplicationController
  skip_after_action :verify_authorized
  respond_to :js

  def index
    run Fault::Index do
      return render 'index', locals: { faults: operation_model }
    end
    failed
  end

  def new
    run Fault::Create::Present do
      return render 'shared/show_modal_form'
    end
    failed
  end

  def create
    run Fault::Create do
      return render 'shared/close_modal_form'
    end
    render 'shared/show_modal_form'
  end

  def destroy
    run Fault::Destroy do
      return render 'destroy'
    end
    failed
  end

  def fault_params
    params.require(:fault)
          .permit(:causer_id, :comment, :date, :kind_id, :penalty)
  end
end
