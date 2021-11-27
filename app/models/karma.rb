# frozen_string_literal: true

class Karma < ApplicationRecord
  GROUP_SIZE = 50

  scope :created_asc, -> { order('karmas.created_at asc') }
  scope :good, -> { where(good: true) }
  scope :bad, -> { where(good: false) }
  scope :used, -> { includes(:karma_group).where('karma_groups.bonus_id != ?', nil) }
  scope :unused, -> { includes(:karma_group).where(karma_groups: { bonus_id: nil }) }
  scope :ungrouped, -> { where(karma_group_id: nil) }
  scope :created_at, ->(date) { where(created_at: date.beginning_of_day..date.end_of_day) }

  belongs_to :user, inverse_of: :karmas
  belongs_to :karma_group, inverse_of: :karmas

  delegate :department, :department_id, to: :user

  # attr_accessible :comment, :user_id, :karma_group_id, :good
  validates_presence_of :user, :comment

  def kind
    good ? 'good' : 'bad'
  end

  def is_grouped?
    karma_group.present?
  end

  def is_ungrouped?
    karma_group.nil?
  end

  def user_presentation
    user.present? ? user.presentation : ''
  end

  def group_with(karma2)
    if is_ungrouped? && good? && karma2.is_ungrouped? && karma2.good?
      new_karma_group = KarmaGroup.create
      update_attributes karma_group_id: new_karma_group.id
      karma2.update_attributes karma_group_id: new_karma_group.id
      true
    else
      false
    end
  end

  def add_to_group(new_karma_group)
    if good?
      old_karma_group = karma_group.present? ? KarmaGroup.find(karma_group_id) : nil
      update_attributes karma_group_id: new_karma_group.id
      old_karma_group.destroy if old_karma_group.present? && old_karma_group.karmas.empty?
      true
    else
      false
    end
  end

  def ungroup
    old_karma_group = KarmaGroup.find karma_group_id
    if update_attributes karma_group_id: nil
      old_karma_group.destroy if old_karma_group.present? && old_karma_group.karmas.empty?
      true
    else
      false
    end
  end
end
