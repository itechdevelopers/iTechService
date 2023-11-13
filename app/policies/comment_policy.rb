class CommentPolicy < BasePolicy
  def create?; true; end

  def update?
    superadmin? || (record.user_id == user.id)
  end
end
