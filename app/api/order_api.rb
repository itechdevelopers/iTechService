class OrderApi < Grape::API
  version 'v1', using: :path
  before {authenticate!}

  desc 'Check order status'
  get 'check_order_status/:ticket_number', requirements: {ticket_number: /[0-9]+/} do
    authorize :read, Order
    if (order = Order.find_by_number(params[:ticket_number])).present?
      order.status_info
    else
      {status: 'not_found'}
    end
  end
end