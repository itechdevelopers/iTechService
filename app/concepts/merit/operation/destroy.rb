class Merit::Destroy < BaseOperation
  step Model(Merit, :find_by)
  failure :record_not_found!
  step Policy::Pundit(MeritPolicy, :destroy?)
  failure :not_authorized!
  step ->(*, model:, **) { model.destroy }
end
