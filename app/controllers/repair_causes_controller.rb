class RepairCausesController < ApplicationController
  def index
    authorize RepairCause
    @modal = "manage_repair_causes"
    @repair_cause_groups = RepairCauseGroup.all

    respond_to do |format|
      format.js { render 'shared/show_modal_form' }
    end
  end

  def new
    authorize RepairCause
    @modal = "repair_causes"
    @repair_cause = RepairCause.new
    respond_to do |format|
      format.js { render "shared/show_modal_form" }
    end
  end

  def create
    @repair_cause = authorize RepairCause.new(repair_cause_params) 
    if new_rcg_params[:repair_cause_group_name].present?
      group_title = new_rcg_params[:repair_cause_group_name]
      new_repair_cause_group = RepairCauseGroup.find_or_create_by(title: group_title)
      @repair_cause.repair_cause_group_id = new_repair_cause_group.id
    end

    respond_to do |format|
      if @repair_cause.save
        format.js
      else
        format.js { render "shared/show_modal_form" }
      end
    end
  end

  def destroy
    @repair_cause = authorize RepairCause.find(params[:id])
    group = @repair_cause.repair_cause_group

    ActiveRecord::Base.transaction do
      @repair_cause.destroy!
      group.destroy! if group.repair_causes.reload.empty?
    end

    respond_to(&:js)
  end

  # GET /repair_causes/for_product/:product_id
  # Возвращает RepairCauseGroup'ы, у которых есть причины, связанные с repair_services данного продукта
  def for_product
    authorize ServiceJob, :create?
    product = Product.find(params[:product_id])

    repair_service_ids = product.repair_service_ids
    repair_cause_ids = RepairCause.joins(:repair_services)
                                  .where(repair_services: { id: repair_service_ids })
                                  .distinct.pluck(:id)

    groups = RepairCauseGroup.joins(:repair_causes)
                             .where(repair_causes: { id: repair_cause_ids })
                             .distinct
                             .map { |g| { id: g.id, title: g.title } }

    render json: groups
  end

  # GET /repair_causes/for_group/:group_id
  # Возвращает RepairCause для группы, отфильтрованные по product_id
  def for_group
    authorize ServiceJob, :create?
    group = RepairCauseGroup.find(params[:group_id])
    product_id = params[:product_id]

    if product_id.present?
      product = Product.find(product_id)
      repair_service_ids = product.repair_service_ids

      causes = group.repair_causes
                    .joins(:repair_services)
                    .where(repair_services: { id: repair_service_ids })
                    .distinct
                    .map { |c| { id: c.id, title: c.title } }
    else
      causes = group.repair_causes.map { |c| { id: c.id, title: c.title } }
    end

    render json: causes
  end

  # GET /repair_causes/:id/repair_services
  # Возвращает RepairServices для причины, отфильтрованные по product_id
  def repair_services
    authorize ServiceJob, :create?
    cause = RepairCause.find(params[:id])
    product_id = params[:product_id]
    department_id = params[:department_id]

    services = cause.repair_services.not_archived

    if product_id.present?
      product = Product.find(product_id)
      services = services.where(id: product.repair_service_ids)
    end

    result = services.map do |s|
      price = s.price(Department.find_by(id: department_id))
      {
        id: s.id,
        name: s.name,
        price: price&.shown_price,
        time_standard: s.time_standard,
        time_standard_from: s.time_standard_from,
        time_standard_to: s.time_standard_to
      }
    end

    render json: result
  end

  private

  def new_rcg_params
    params.require(:repair_cause).permit(:repair_cause_group_name)
  end

  def repair_cause_params
    params.require(:repair_cause).permit(:title, :repair_cause_group_id)
  end
end
