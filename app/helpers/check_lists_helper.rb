module CheckListsHelper
  def available_check_lists_for(entity_type)
    CheckList.active.for_entity(entity_type)
  end

  def prepare_check_list_responses_for(model, entity_type)
    available_lists = available_check_lists_for(entity_type)
    
    available_lists.map do |check_list|
      existing = model.check_list_responses&.find { |r| r.check_list_id == check_list.id }
      existing || model.check_list_responses.build(check_list: check_list)
    end
  end

  def check_list_responses_hash_for(model, entity_type)
    prepare_check_list_responses_for(model, entity_type).index_by(&:check_list_id)
  end

  def check_list_items_for(check_list)
    check_list.check_list_items.ordered
  end

  def response_for_item(response, item)
    return false unless response.persisted?
    response.answer_for_item(item.id) || false
  end
end
