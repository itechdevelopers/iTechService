module TradeInDevice::Cell
  class Show < Preview
    private

    include FormHelper

    property :appraiser, :bought_device, :client_name, :client_phone, :check_icloud, :archiving_comment,
             :condition, :number

    delegate :human_attribute_name, to: :TradeInDevice
    delegate :name, :presentation, to: :decorated_item

    def attribute_presentation(attr_name)
      content_tag :tr do
        content_tag(:td, human_attribute_name(attr_name)) +
          content_tag(:td, send(attr_name))
      end
    end

    def check_lists_answers
      result = ''
      model.available_check_lists.each do |check_list|
        result << content_tag(:h4, check_list.name)
        result << content_tag(:p) do
          p_result = ''
          check_list.check_list_items.ordered.each do |question|
            response = model.check_list_response_for(check_list)
            p_result << check_for_item(response, question)
            p_result << question.question
            p_result << content_tag(:br)
          end
          p_result
        end
      end
      result
    end

    def check_for_item(response, question)
      if response&.answer_for_item(question.id)
        "#{glyph(:check)} "
      else
        "#{glyph(:times)} "
      end
    end

    def item
      link_to presentation, device_path(model.item), remote: true
    end

    def received_at
      l model.received_at, format: :date
    end

    def archived
      TradeInDevice.human_attribute_name("archived/#{model.archived}")
    end

    def client
      return unless model.client_id

      link_to model.client&.presentation, client_path(model.client_id)
    end

    def department
      model.department.name
    end

    def comments
      cell Comment::Cell::Preview, collection: model.comments.oldest
    end

    def comment_form
      cell Comment::Cell::Form, model.comments.build
    end

    def link_to_index
      link_to t('.index.title'), trade_in_devices_path
    end

    def link_to_print
      link_to t('helpers.links.print'), print_trade_in_device_path(id), target: '_blank', class: 'btn btn-default'
    end

    def link_to_edit
      link_to t('helpers.links.edit'), edit_trade_in_device_path(id), class: 'btn btn-default'
    end

    def link_to_destroy
      link_to t('helpers.links.destroy'), trade_in_device_path(id), method: 'delete', data: {confirm: t('helpers.links.confirm', default: 'Are you sure?')}, class: 'btn btn-danger'
    end
  end
end
