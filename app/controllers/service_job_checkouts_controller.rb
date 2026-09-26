# frozen_string_literal: true

# Списки контроля по оплате через 1С. Три вкладки — три разные незакрытые
# ситуации: расчёт начат и брошен, работа закрыта без подтверждения от 1С,
# деньги вернули клиенту.
class ServiceJobCheckoutsController < ApplicationController
  TABS = %w[awaiting_payment awaiting_confirmation returned].freeze

  def index
    authorize ServiceJobCheckout

    @tab = TABS.include?(params[:tab]) ? params[:tab] : TABS.first
    @counts = TABS.each_with_object({}) { |tab, counts| counts[tab] = scope_for(tab).count }
    @checkouts = scope_for(@tab).includes(:initiator, :confirmed_by, service_job: %i[client location])
                                .recent_first
  end

  def confirm
    checkout = authorize ServiceJobCheckout.find(params[:id])
    number = params[:check_number].to_s.strip

    checkout.update!(check_number: number.presence || checkout.check_number,
                     confirmed_by: current_user,
                     confirmed_at: Time.current)

    redirect_to service_job_checkouts_path(tab: 'awaiting_confirmation'),
                notice: t('.confirmed', number: checkout.check_number)
  end

  private

  def scope_for(tab)
    ServiceJobCheckout.public_send(tab)
  end
end
