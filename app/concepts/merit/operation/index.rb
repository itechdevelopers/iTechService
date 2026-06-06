class Merit::Index < BaseOperation
  step ->(options, params:, current_user:, **) {
    merits = if current_user.any_admin? || current_user.id == params[:user_id].to_i
               Merit.where(recipient_id: params[:user_id])
             else
               Merit.none
             end
    options['model'] = merits.ordered.page(params[:page])
  }
end
