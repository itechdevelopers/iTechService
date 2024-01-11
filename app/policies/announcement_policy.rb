class AnnouncementPolicy < BasePolicy
  def make_announce?
    !has_role?(:supervisor)
  end

  def close?
    same_department? && record.visible_for?(user)
  end

  def close_all?; true end

  def update?
    (same_department? && any_admin?) ||
      (record.user_id == user.id) ||
      ((record.order_done? || record.order_status?) && (user.media?))
  end

  def cancel_announce?
    true
  end

  def see_bad_reviews?
    superadmin? || able_to?(:view_bad_review_announcements)
  end

  def close_bad_review?
    superadmin?
  end
end
