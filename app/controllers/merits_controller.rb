# frozen_string_literal: true

class MeritsController < ApplicationController
  skip_after_action :verify_authorized
  respond_to :js

  def index
    run Merit::Index do
      return render 'index', locals: { merits: operation_model }
    end
    failed
  end

  def new
    run Merit::Create::Present do
      return render 'shared/show_modal_form'
    end
    failed
  end

  def create
    run Merit::Create do
      return render 'create'
    end
    render 'shared/show_modal_form'
  end

  def destroy
    run Merit::Destroy do
      return render 'destroy'
    end
    failed
  end

  def merit_params
    params.require(:merit)
          .permit(:recipient_id, :comment, :date, :issued_by_id)
  end
end
