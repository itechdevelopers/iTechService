# frozen_string_literal: true

class MovementAct < ApplicationRecord
  include Document

  scope :posted, -> { where(status: 1) }
  scope :deleted, -> { where(status: 2) }

  belongs_to :user
  belongs_to :store
  belongs_to :dst_store, class_name: 'Store'
  has_many :movement_items, dependent: :destroy, inverse_of: :movement_act

  accepts_nested_attributes_for :movement_items, allow_destroy: true,
                                reject_if: lambda { |a| a[:item_id].blank? || a[:quantity].blank? }

  delegate :name, to: :store, prefix: true, allow_nil: true
  delegate :name, to: :dst_store, prefix: true, allow_nil: true

  validates_presence_of :date, :dst_store, :store, :status, :user
  validates_presence_of :comment, if: :is_to_defect?
  validates_inclusion_of :status, in: Document::STATUSES.keys
  validate :stores_must_be_different
  before_validation :set_user

  after_initialize do
    self.user_id ||= User.try(:current).try(:id)
    self.date ||= DateTime.current
    self.status ||= 0
  end

  def self.search(params)
    movement_acts = MovementAct.all

    unless (start_date = params[:start_date]).blank?
      movement_acts = movement_acts.where('date >= ?', start_date.to_date)
    end

    unless (end_date = params[:end_date]).blank?
      movement_acts = movement_acts.where('date <= ?', end_date.to_date)
    end

    unless (store_id = params[:store_id]).blank?
      movement_acts = movement_acts.where store_id: store_id
    end

    unless (dst_store_id = params[:dst_store_id]).blank?
      movement_acts = movement_acts.where dst_store_id: dst_store_id
    end

    unless (q = params[:q]).blank?
      movement_acts = movement_acts.where id: q
    end

    movement_acts
  end

  def is_insufficient?
    movement_items.any?(&:is_insufficient?)
  end

  def post
    if is_valid_for_posting?
      transaction do
        movement_items.each do |movement_item|
          movement_item.store_item(store).move_to dst_store, movement_item.quantity
        end
        update! status: 1, date: DateTime.current, user_id: User.current.id
      end
    else
      false
    end
  end

  def unpost
    return false unless is_valid_for_unposting?

    transaction do
      movement_items.each do |movement_item|
        movement_item.store_item(dst_store).move_to(store, movement_item.quantity)
      end
      update_attribute :status, 0
    end
  end

  def is_from_spare_parts?
    store.is_spare_parts?
  end

  def is_to_defect?
    dst_store.is_defect?
  end

  def is_spare_parts_to_defect?
    store.is_spare_parts? && dst_store.is_defect?
  end

  private

  def stores_must_be_different
    if store_id == dst_store_id
      msg = I18n.t 'movement_acts.errors.stores_same'
      errors.add :store_id, msg
      errors.add :dst_store_id, msg
    end
  end

  def set_user
    self.user_id ||= User.try(:current).try(:id)
  end

  def is_valid_for_posting?
    is_valid = true
    if is_new?
      movement_items.each do |movement_item|
        if movement_item.is_insufficient?
          errors[:base] << I18n.t('movement_acts.errors.insufficient', product: movement_item.name)
          is_valid = false
        end
        unless movement_item.has_prices_for_store?(dst_store)
          errors[:base] << I18n.t('movement_acts.errors.prices_undefined', product: movement_item.name)
          is_valid = false
        end
      end
    else
      errors[:base] << I18n.t('documents.errors.cannot_be_posted')
      is_valid = false
    end
    is_valid
  end

  def is_valid_for_unposting?
    result = true

    if is_posted?
      movement_items.each do |movement_item|
        if movement_item.quantity_in_store(dst_store) < movement_item.quantity
          errors[:base] << I18n.t('movement_acts.errors.insufficient', product: movement_item.name)
          result = false
        end
      end
    else
      errors[:base] << I18n.t('documents.errors.must_be_posted')
      result = false
    end

    result
  end
end
