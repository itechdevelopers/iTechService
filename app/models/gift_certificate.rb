# frozen_string_literal: true

class GiftCertificate < ActiveRecord::Base
  STATUSES = %w[available issued used].freeze
  NOMINAL_MIN = 1000
  NOMINAL_MAX = 100_000
  NOMINAL_STEP = 500

  belongs_to :department, required: true
  has_many :payments, dependent: :nullify
  has_many :history_records, as: :object, dependent: :destroy
  validates :number, presence: true, uniqueness: { case_sensitive: false }
  validates :nominal, presence: true,
                      numericality: { only_integer: true, greater_than_or_equal_to: NOMINAL_MIN, less_than_or_equal_to: NOMINAL_MAX }
  before_validation { |cert| cert.status ||= 0 }
  before_validation :validate_consumption
  before_validation :validate_status, on: :update
  after_validation :nominal_must_be_multiple_of_step

  def self.search(params)
    certificates = GiftCertificate.all

    if (q = params[:search_q]).present?
      certificates = certificates.where 'LOWER(number) = ? OR id = ?', q.mb_chars.downcase.to_s, q.to_i
    end
    certificates
  end

  def self.find_by_number(number)
    where('LOWER(number) = ?', number.mb_chars.downcase.to_s).first
  end

  def status_s
    STATUSES[status]
  end

  def status_h
    I18n.t("gift_certificates.statuses.#{status_s}")
  end

  def issue
    update_attributes status: 1
  end

  def refresh
    update_attributes status: 0, consumed: 0
  end

  def available?
    status.zero?
  end

  def issued?
    status == 1
  end

  def used?
    status == 2
  end

  def consume=(amount)
    self.consumed = (consumed || 0) + amount
    self.status = 2 if consumed == nominal
    save
  end

  def balance
    nominal - (consumed || 0)
  end

  def issued_at
    history_records.where(column_name: 'status', new_value: '1').last.try(:created_at)
  end

  def history_since_issue
    if issued?
      history_records.where('created_at >= ? AND column_name IN (?)', issued_at, %w[status consumed])
    else
      []
    end
  end

  private

  def validate_status
    if (old_status = changed_attributes['status'].present? ? changed_attributes['status'].to_i : nil).present?
      errors.add :base, I18n.t('gift_certificates.errors.not_available') if issued? && (old_status != 0)
      errors.add :base, I18n.t('gift_certificates.errors.not_issued') if used? && (old_status != 1)
      errors.add :base, I18n.t('gift_certificates.errors.not_used') if available? && (old_status != 2)
    end
  end

  def validate_consumption
    if changed_attributes['consumed'].present?
      if issued? || used?
        errors.add :base, I18n.t('gift_certificates.errors.consumption_exceeded') unless (consumed || 0) <= nominal
      elsif consumed != 0
        errors.add :base, I18n.t('gift_certificates.errors.not_issued')
      end
    end
  end

  def nominal_must_be_multiple_of_step
    return unless nominal

    errors.add :nominal, :multiple_of, step: NOMINAL_STEP if (nominal % NOMINAL_STEP).positive?
  end
end
