class RepairApi < Grape::API
  version 'v1', using: :path
  before { authenticate! }

  desc 'Get repair services info'
  params do
    optional :group_id, type: Integer
  end
  get 'repair_services' do
    authorize :read, RepairService
    if (store = current_user.spare_parts_store).present?
      if params[:group_id].present?
        repair_group = RepairGroup.find(params[:group_id])
        repair_groups = repair_group.children
        repair_services = repair_group.repair_services
        present :repair_services, repair_services, with: Entities::RepairServiceEntity, store: store
      else
        repair_groups = RepairGroup.roots
      end
      present :groups, repair_groups, with: Entities::RepairGroupEntity
    else
      error!({error: 'Spare parts store undefined'}, 404)
    end
  end
end
