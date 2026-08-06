# frozen_string_literal: true

# Technician's self-report about breaking a device while repairing it:
# circumstances, how it was resolved and the spare part installed instead of
# the broken one. The part price is snapshotted on create, because item prices
# drift with new batches while the report must keep the cost at that moment.
class BreakageReport < ApplicationRecord
  include Auditable

  WRITE_OFF_QUANTITY = 1

  scope :in_department, ->(department) { where(service_job_id: ServiceJob.in_department(department)) }
  scope :newest_first, -> { order(created_at: :desc) }

  belongs_to :service_job
  belongs_to :device_task, optional: true
  belongs_to :user
  belongs_to :item, optional: true
  belongs_to :deduction_act, optional: true

  delegate :ticket_number, :presentation, to: :service_job, allow_nil: true

  validates :circumstances, :resolution, presence: true
  validate :single_report_per_job
  validate :spare_part_available, if: -> { item.present? && item_id_changed? }

  before_validation :set_service_job, :set_user
  before_save :snapshot_part_price, if: :item_id_changed?
  after_save :sync_write_off, if: :saved_change_to_item_id?

  audited associated_with: :service_job

  def item_presentation
    item&.presentation
  end

  # Branch spare parts store the part is written off from.
  def write_off_store
    service_job&.department&.spare_parts_store
  end

  private

  def set_service_job
    self.service_job ||= device_task&.service_job
  end

  def set_user
    self.user ||= User.current
  end

  def snapshot_part_price
    self.part_price = item&.purchase_price
  end

  # One report per service job — the technician edits the existing one instead
  # of stacking new ones.
  def single_report_per_job
    return if service_job_id.blank?

    siblings = BreakageReport.where(service_job_id: service_job_id)
    siblings = siblings.where.not(id: id) if persisted?

    errors.add(:base, I18n.t('breakage_reports.errors.duplicate')) if siblings.exists?
  end

  def available_quantity
    item.store_items.in_store(write_off_store).sum(:quantity)
  end

  def spare_part_available
    return if write_off_store.blank?

    return if available_quantity >= WRITE_OFF_QUANTITY

    errors.add(:item_id, :insufficient, store: write_off_store.name)
  end

  # Swapping the part rewrites the write-off: the previous act is reverted and
  # marked as deleted, a fresh one is posted for the new part.
  def sync_write_off
    revert_write_off
    write_off_spare_part
  end

  def revert_write_off
    return if deduction_act.blank?

    deduction_act.unpost
    deduction_act.update_column(:status, Document::STATUSES.key('deleted'))
    update_column(:deduction_act_id, nil)
  end

  # The part goes straight to zero from the branch store — same outcome as the
  # regular repair write-off, but as a DeductionAct, because only a document
  # carries the reason («основание») the stock keeper asked for.
  def write_off_spare_part
    return if item.blank? || write_off_store.blank?

    act = DeductionAct.create!(store: write_off_store,
                               comment: write_off_comment,
                               deduction_items_attributes: [{ item_id: item_id, quantity: WRITE_OFF_QUANTITY }])

    raise ActiveRecord::RecordInvalid, self unless act.post

    update_column(:deduction_act_id, act.id)
  end

  def write_off_comment
    I18n.t('breakage_reports.write_off_comment',
           ticket: service_job&.ticket_number, user: user&.short_name)
  end
end
