# frozen_string_literal: true

class Purchase < ApplicationRecord
  include Document

  scope :posted, -> { where(status: 1) }
  scope :deleted, -> { where(status: 2) }

  belongs_to :contractor, inverse_of: :purchases
  belongs_to :store, inverse_of: :purchases
  has_many :batches, inverse_of: :purchase, dependent: :destroy
  has_many :items, through: :batches
  accepts_nested_attributes_for :batches, allow_destroy: true, reject_if: lambda { |a|
                                                                            a[:id].blank? && (a[:price].blank? || a[:quantity].blank? || a[:item_id].blank?)
                                                                          }
  validates_presence_of :contractor, :store, :status, :date
  validates_inclusion_of :status, in: Document::STATUSES.keys
  validates_associated :batches

  after_initialize do
    self.date ||= DateTime.current
    self.status ||= 0
  end

  def self.search(params)
    purchases = Purchase.all

    unless (purchase_q = params[:purchase_q]).blank?
      purchases = purchases.where(id: purchase_q)
    end

    unless (start_date = params[:start_date]).blank?
      purchases = purchases.where('created_at >= ?', start_date.to_date)
    end

    unless (end_date = params[:end_date]).blank?
      purchases = purchases.where('created_at <= ?', end_date.to_date)
    end

    unless (contractor_id = params[:contractor_id]).blank?
      purchases = purchases.where(contractor_id: contractor_id)
    end

    unless (store_id = params[:store_id]).blank?
      purchases = purchases.where(store_id: store_id)
    end

    purchases
  end

  def contractor_name
    contractor.try :name
  end

  def store_name
    store.try :name
  end

  def total_sum
    batches.to_a.sum(&:sum)
  end

  def post
    if is_valid_for_posting?
      transaction do
        cur_date = DateTime.current

        batches.each do |batch|
          unless skip_revaluation?
            price_type = PriceType.purchase
            new_price = if batch.product.quantity_in_store.positive?
                          (batch.product.remnants_cost + batch.sum) / (batch.product.quantity_in_store + batch.quantity)
                        else
                          batch.price
                        end
            batch.prices.create price_type_id: price_type.id, date: cur_date, value: new_price
          end

          if batch.feature_accounting
            if batch.store_item.present?
              batch.store_item.update_attributes(store_id: store_id)
            else
              StoreItem.create(
                store_id: store_id, item_id: batch.item_id, quantity: 1
              )
            end
          else
            batch.store_item(store).add batch.quantity
          end
        end

        update_attribute :status, 1
        update_attribute :date, cur_date
      end
    else
      false
    end
  end

  def update_prices(new_attributes)
    if is_posted?
      transaction do
        update new_attributes

        batches.each do |batch|
          next if skip_revaluation?

          price = batch.prices.purchase.find_for_time_or_date(date)
          previous_price = price.find_previous

          new_value = if previous_price.present?
                        remnants_quantity = batch.product.quantity_in_store - batch.quantity
                        remnants_cost = remnants_quantity * previous_price.value
                        (remnants_cost + batch.sum) / (remnants_quantity + batch.quantity)
                      else
                        batch.price
                      end
          price.update value: new_value
        end
      end
    end
  end

  # def unpost
  #   if is_posted?
  #     transaction do
  #       batches.each do |batch|
  #         batch.remove_from_store
  #
  #         unless skip_revaluation?
  #           price = batch.prices.purchase.find_for_time_or_date(date)
  #           price.destroy
  #         end
  #       end
  #
  #       update_attribute :status, 0
  #       update_attribute :date, nil
  #     end
  #   else
  #     errors[:base] << 'Приход не проведён!'
  #     false
  #   end
  # end

  def build_revaluation_act(product_ids = nil)
    RevaluationAct.new product_ids: product_ids
  end

  def build_movement_act(selected_item_ids = nil)
    movement_items_attributes = []
    dst_store_id = nil
    (selected_item_ids || item_ids).map do |item_id|
      if (batch = batches.where(item_id: item_id).first).present?
        movement_items_attributes << { item_id: item_id, quantity: batch.quantity }
        dst_store_id ||= batch.is_spare_part ? Store.for_spare_parts&.id : Store.for_retail&.id
      end
    end
    MovementAct.new store_id: store_id, dst_store_id: dst_store_id, movement_items_attributes: movement_items_attributes
  end

  private

  def is_valid_for_posting?
    is_valid = true
    if is_new?
      batches.each do |batch|
        if batch.feature_accounting && batch.store_item.present?
          errors[:base] << I18n.t('purchases.errors.store_item_already_present', product: batch.name)
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
