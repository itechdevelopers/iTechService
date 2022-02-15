class Salary < ApplicationRecord
  default_scope { order('issued_at desc') }

  scope :in_department, ->(department) { where(user_id: User.in_department(department)) }
  scope :ordered, -> { order('issued_at desc') }
  scope :issued_at, ->(period) { where(issued_at: period) }
  scope :salary, -> { where(is_prepayment: [false, nil]) }
  scope :prepayment, -> { where(is_prepayment: true) }

  belongs_to :user, inverse_of: :salaries, optional: true
  has_many :comments, as: :commentable, dependent: :destroy

  # attr_accessible :amount, :user, :user_id, :issued_at, :comment, :is_prepayment
  validates_presence_of :user, :amount
  attr_accessor :comment

  delegate :department, :department_id, to: :user

  def self.search(params)
    salaries = Salary.ordered.includes :user
    unless (user_q = params[:user_q]).blank?
      salaries = salaries.where 'LOWER(users.name) LIKE :q OR LOWER(users.surname) LIKE :q', q: "%#{user_q.mb_chars.downcase.to_s}%"
    end
    salaries
  end

  def comment=(content)
    comments.build content: content unless content.blank?
  end

  def prepayments
    prev_salary_date = user.salaries.salary.where('issued_at < ?', issued_at).maximum('issued_at')
    if prev_salary_date.present?
      user.salaries.prepayment.issued_at prev_salary_date..issued_at
    else
      user.salaries.prepayment.where('issued_at < ?', issued_at)
    end
  end

  def prepayments_amount
    prepayments.sum :amount
  end

  def full_amount
    amount + prepayments_amount
  end

end
