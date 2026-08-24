# frozen_string_literal: true

# Spare part picker for the «Я сломал» block. Besides the product catalogue it
# offers the way technicians actually think — the repair they would have done —
# and takes the part attached to that repair service. Nothing of the service
# itself lands in the report: it is only a road to the item.
class BreakagePartsController < ApplicationController
  respond_to :js

  def choose
    authorize :breakage_part
    @product_groups = ProductGroup.search(**product_group_search_params).ordered
    @repair_groups = RepairGroup.not_archived.roots.order('name asc')
  end

  def index
    authorize :breakage_part
    @repair_services = if params[:group].present?
                         RepairService.not_archived
                                      .includes(spare_parts: { product: :items })
                                      .in_group(params[:group])
                       else
                         RepairService.none
                       end
  end

  private

  def product_group_search_params
    params.permit(:form, :store_kind, :user_role).to_h.symbolize_keys.merge(roots: true)
  end
end
