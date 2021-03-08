# frozen_string_literal: true

class FaultKindsController < ApplicationController
  skip_after_action :verify_authorized
  respond_to :html

  def index
    run FaultKind::Index do
      return render 'index', locals: { fault_kinds: operation_model }
    end
    failed
  end

  def new
    run FaultKind::Create::Present do
      return render 'new'
    end
    failed
  end

  def create
    run FaultKind::Create do
      return redirect_to_index notice: operation_message
    end
    render 'new'
  end

  def edit
    run FaultKind::Update::Present do
      return render 'edit'
    end
    failed
  end

  def update
    run FaultKind::Update do
      return redirect_to_index notice: operation_message
    end
    render 'edit'
  end

  def destroy
    run FaultKind::Destroy do
      return redirect_to_index notice: operation_message
    end
    redirect_to_index alert: operation_message
  end

  def fault_kind_params
    params.require(:fault_kind)
          .permit(:description, :financial, :icon, :is_permanent, :name, :penalties)
  end
end
