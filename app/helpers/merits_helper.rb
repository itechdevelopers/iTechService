module MeritsHelper
  def merit_recipients_collection
    User.active.staff.order(:name)
  end
end
