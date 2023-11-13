class OrderNotePolicy < BasePolicy
  def create?; true; end

  def update?
    superadmin? || (record.author_id == user.id)
  end
end
