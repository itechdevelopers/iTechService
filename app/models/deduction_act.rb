# frozen_string_literal: true

class DeductionAct < ApplicationRecord
  include Document
  scope :posted, -> { where(status: 1) }
  scope :deleted, -> { where(status: 2) }
  belongs_to :store, optional: true
  belongs_to :user, optional: true
  has_many :deduction_items, inverse_of: :deduction_act, dependent: :destroy
  accepts_nested_attributes_for :deduction_items, allow_destroy: true
  delegate :name, to: :store, prefix: true, allow_nil: true
  # attr_accessible :date, :status, :store_id, :comment, :deduction_items_attributes
  validates_presence_of :status, :date, :store, :comment
  validates_inclusion_of :status, in: Document::STATUSES.keys
  before_validation :set_user

  after_initialize do
    self.user_id ||= User.try(:current).try(:id)
    self.date ||= DateTime.current
  end

  def self.search(params)
    deduction_acts = DeductionAct.all

    unless (start_date = params[:start_date]).blank?
      deduction_acts = deduction_acts.where('date >= ?', start_date.to_date)
    end

    unless (end_date = params[:end_date]).blank?
      deduction_acts = deduction_acts.where('date <= ?', end_date.to_date)
    end

    unless (store_id = params[:store_id]).blank?
      deduction_acts = deduction_acts.where store_id: store_id
    end

    if (q = params[:q]).present?
      deduction_acts = deduction_acts.where id: q
    end

    deduction_acts
  end

  def post
    if is_valid_for_posting?
      transaction do
        deduction_items.each do |deduction_item|
          deduction_item.remove_from_store store, deduction_item.quantity
        end
        update_attribute :user_id, User.try(:current).try(:id)
        update_attribute :date, DateTime.current
        update_attribute :status, 1
      end
    else
      false
    end
  end

  private

  def set_user
    self.user_id ||= User.try(:current).try(:id)
  end

  def is_valid_for_posting?
    is_valid = true
    if is_new?
      deduction_items.each do |deduction_item|
        if deduction_item.is_insufficient?
          errors[:base] << I18n.t('deduction_acts.errors.insufficient', product: deduction_item.name)
          is_valid = false
        end
      end
    else
      errors[:base] << I18n.t('documents.errors.cannot_be_posted')
      is_valid = false
    end
    is_valid
  end
end
