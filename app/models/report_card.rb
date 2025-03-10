class ReportCard < ApplicationRecord
  belongs_to :report_column

  has_many :report_permissions, dependent: :destroy
  has_many :authorized_users, through: :report_permissions, source: :user
  
  def accessible_by?(user)
    # Если пользователь имеет права суперадминистратора, доступ разрешен
    return true if user.superadmin?
    
    authorized_users.include?(user)
  end
end
