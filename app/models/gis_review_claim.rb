# frozen_string_literal: true

# Заявка сотрудника «этот отзыв оставлен мне». Модератор подтверждает или
# отклоняет её. Записи не удаляются: по ним видно, каким образом отзыв оказался
# привязан к человеку.
class GisReviewClaim < ApplicationRecord
  belongs_to :gis_review
  belongs_to :user
  belongs_to :resolved_by, class_name: 'User', optional: true

  has_many :notifications, as: :referenceable, dependent: :destroy

  audited

  enum status: { pending: 0, approved: 1, rejected: 2 }

  scope :recent,   -> { order(created_at: :desc) }
  scope :resolved, -> { where.not(status: :pending) }

  validates :gis_review_id, uniqueness: { scope: :user_id }
  validate :review_must_be_unassigned, on: :create

  # Подтверждение: привязываем отзыв к автору заявки и отклоняем остальные
  # заявки по этому же отзыву — иначе два «Кирилла» навсегда остались бы
  # в статусе «ожидает». Всё одной транзакцией: наполовину применённое
  # состояние здесь хуже, чем неудача целиком.
  def approve!(moderator)
    # Список соперничающих заявок берём ДО транзакции: после resolve! они уже
    # не pending, и scope их не найдёт — уведомлять было бы некого.
    others = competing_claims

    transaction do
      resolve!(:approved, moderator)
      gis_review.update!(user: user, assigned_by: moderator, status: :assigned)
      others.each { |claim| claim.resolve!(:rejected, moderator) }
    end

    notify_author('Ваша заявка на отзыв подтверждена')
    others.each { |claim| claim.notify_author('Отзыв закреплён за другим сотрудником') }
  end

  def reject!(moderator)
    resolve!(:rejected, moderator)
    notify_author('Ваша заявка на отзыв отклонена')
  end

  def resolve!(new_status, moderator)
    update!(status: new_status, resolved_by: moderator, resolved_at: Time.current)
  end

  # Только колокольчик, без Телеграма: заявок кратно больше, чем негативных
  # отзывов, и личные сообщения по каждой превратились бы в шум.
  def notify_author(message)
    notify(user, "#{message}: #{gis_review.short_label}")
  end

  def notify_moderators
    GisReviewClaim.moderators.each do |moderator|
      notify(moderator, "#{user.short_name} просит закрепить за собой отзыв: #{gis_review.short_label}")
    end
  end

  # Те же, кто работает с негативом: суперадмины и обладатели права
  # manage_negative_reviews.
  def self.moderators
    (User.superadmins.active.to_a +
      User.active.joins(:abilities).where(abilities: { name: 'manage_negative_reviews' }).to_a).uniq
  end

  private

  def competing_claims
    GisReviewClaim.where(gis_review_id: gis_review_id).where.not(id: id).pending.to_a
  end

  def notify(recipient, message)
    notification = Notification.create!(
      user: recipient,
      message: message,
      url: Rails.application.routes.url_helpers.claims_gis_reviews_path,
      referenceable: self
    )
    UserNotificationChannel.broadcast_to(recipient, notification)
  end

  # Заявку имеет смысл подавать только на неразобранный отзыв.
  def review_must_be_unassigned
    return if gis_review.nil? || gis_review.need_assignment?

    errors.add(:gis_review, 'уже привязан к сотруднику')
  end
end
