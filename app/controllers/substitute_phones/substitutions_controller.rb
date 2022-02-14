module SubstitutePhones
  class SubstitutionsController < ApplicationController
    skip_after_action :verify_authorized
    respond_to :html

    def edit
      run PhoneSubstitution::Update::Present do
        return render_form
      end
      failed
    end

    def update
      run PhoneSubstitution::Update do
        return redirect_to substitute_phone_path(operation_model.substitute_phone_id), notice: operation_message
      end
      render_form
    end

    private

    def render_form
      render_cell PhoneSubstitution::Cell::EditForm, model: operation_contract
    end
  end
end