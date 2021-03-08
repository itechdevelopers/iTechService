# frozen_string_literal: true

class RevaluationAct < ActiveRecord::Base
  include Document

  belongs_to :price_type, inverse_of: :revaluation_acts
  has_many :revaluations, inverse_of: :revaluation_act, dependent: :destroy
  accepts_nested_attributes_for :revaluations, allow_destroy: true, reject_if: lambda { |a|
                                                                                 a[:product_id].blank? or a[:price].blank?
                                                                               }
  # attr_accessor :product_ids
  validates_presence_of :price_type, :date, :status
  validates_inclusion_of :status, in: Document::STATUSES.keys

  scope :posted, -> { where(status: 1) }
  scope :deleted, -> { where(status: 2) }

  after_initialize do
    self.status = 'new' if status.blank?
    self.date ||= DateTime.current
    self.price_type_id ||= PriceType.retail.id
  end

  def self.search(params)
    revaluation_acts = RevaluationAct.all

    unless (q = params[:q]).blank?
      revaluation_acts = revaluation_acts.where('id LIKE ?', "%#{q}%")
    end

    unless (start_date = params[:start_date]).blank?
      revaluation_acts = revaluation_acts.where('created_at >= ?', start_date.to_date)
    end

    unless (end_date = params[:end_date]).blank?
      revaluation_acts = revaluation_acts.where('created_at <= ?', end_date.to_date)
    end

    unless (price_type_id = params[:price_type_id]).blank?
      revaluation_acts = revaluation_acts.where(price_type_id: price_type_id)
    end

    revaluation_acts
  end

  def price_type_name
    price_type.present? ? price_type.name : ''
  end

  def post
    if is_valid_for_posting?
      transaction do
        cur_time = Time.current
        revaluations.each do |revaluation|
          ProductPrice.create(product_id: revaluation.product_id, price_type_id: self.price_type_id, date: cur_time,
                              value: revaluation.price)
        end
        update_attribute :status, 1
        update_attribute :date, DateTime.current
      end
    else
      false
    end
  end

  def product_ids=(product_ids)
    if product_ids.present?
      product_ids.split(',').each do |product_id|
        revaluations.build product_id: product_id
      end
    end
  end

  def is_valid_for_posting?
    is_valid = true
    unless is_new?
      errors[:base] << I18n.t('documents.errors.cannot_be_posted')
      is_valid = false
    end
    is_valid
  end
end
