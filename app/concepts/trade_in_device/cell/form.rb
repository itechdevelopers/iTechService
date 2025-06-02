module TradeInDevice::Cell
  class Form < BaseCell
    self.translation_path = 'trade_in_device'

    private

    include FormCell
    include ClientsHelper
    include ActionView::Helpers::FormOptionsHelper
    include ActionView::Helpers::DateHelper

    def header_tag
      content_tag :div, class: 'page-header' do
        content_tag :h2, "#{link_to_index} #{content_tag(:span, '/', class: 'muted')} #{page_title}"
      end
    end

    def page_title
      action_name = model.persisted? ? 'edit' : 'new'
      t ".form.title.#{action_name}"
    end

    def link_to_index
      link_to t('.index.title'), trade_in_devices_path
    end

    def able_to_manage_trade_in?
      current_user.able_to?(:manage_trade_in)
    end

    def persisted?
      model.persisted?
    end

    def replacement_statuses
      TradeInDevice.replacement_statuses.map do |name, _|
        [TradeInDevice.human_attribute_name("replacement_status/#{name}"), name]
      end
    end

    def departments
      Department.select(:id, :name).selectable.map { |department| [department.name, department.id] }
    end
  
    def available_check_lists
      @available_check_lists ||= CheckList.active.for_entity('TradeInDevice')
    end

    def check_list_responses
      @check_list_resposnses ||= prepare_check_list_responses
    end

    def check_list_responses_hash
      @check_list_responses_hash ||= check_list_responses.index_by(&:check_list_id)
    end

    def prepare_check_list_responses
      available_check_lists.map do |check_list|
        existing = model.check_list_responses.find { |r| r.check_list_id == check_list.id }
        response = existing || model.check_list_responses.build(check_list: check_list)
        response
      end
    end

    def check_list_items_for(check_list)
      check_list.check_list_items.ordered
    end

    def response_for_item(response, item)
      return false unless response.persisted?
      response.answer_for_item(item.id) || false
    end
  end
end
