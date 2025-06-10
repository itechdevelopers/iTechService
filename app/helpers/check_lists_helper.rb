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

  def render_check_lists_answers_for(model, entity_type)
    available_lists = available_check_lists_for(entity_type)
    return '' if available_lists.empty?

    result = ''
    available_lists.each do |check_list|
      result << content_tag(:h4, check_list.name)
      result << content_tag(:p) do
        p_result = ''
        check_list.check_list_items.ordered.each do |question|
          response = check_list_response_for(model, check_list)
          p_result << check_mark_for_item(response, question)
          p_result << question.question
          p_result << tag(:br)
        end
        p_result.html_safe
      end
    end
    result.html_safe
  end

  def check_list_response_for(model, check_list)
    model.check_list_responses.find { |r| r.check_list_id == check_list.id }
  end

  def check_mark_for_item(response, question)
    if response&.answer_for_item(question.id)
      "#{icon_tag('check')} ".html_safe
    else
      "#{icon_tag('times')} ".html_safe
    end
  end
end
