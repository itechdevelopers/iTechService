class QuickOrderApi < Grape::API
  version 'v1', using: :path

  desc 'Quick Tasks list'
  get 'quick_tasks' do
    QuickTask.all.as_json(only: [:id, :name])
  end

  desc 'Create Quick Order'
  params do
    requires :quick_order
  end
  post 'quick_orders' do
    authenticate!
    authorize :create, QuickOrder
    quick_order = QuickOrder.new(params[:quick_order])
    if quick_order.save
      pdf = QuickOrderPdf.new quick_order
      filepath = "#{Rails.root.to_s}/tmp/pdf/quick_order_#{quick_order.number}.pdf"
      pdf.render_file filepath
      PrinterTools.print_file filepath, type: :quick_order, printer: quick_order.department.printer
      present quick_order
    else
      error!({error: quick_order.errors.full_messages.join('. ')}, 422)
    end
  end

  desc 'Create media menu order'
  params do
    requires :orders
  end
  post 'media_menu_orders' do
    TYPES = {0 => 'Книги', 1 => 'Приложения', 2 => 'Музыка', 3 => 'Телешоу', 4 => 'Фильмы', 5 => 'Аудиокниги'}
    orders = params[:orders]
    orders.each do |_, order|
      items = {}
      order['items'].each do |item|
        order_item = "	•	#{item['filmNumber']} - #{item[:name]}"
        item_type = TYPES[item['classType']]
        items[item_type] = [] unless items[item_type].present?
        items[item_type] << order_item
      end
      content = ''
      items.each do |_type, _items|
        content << "#{_type}\n\n#{_items.join("\n")}"
      end
      MediaOrder.create time: order[:date], name: order[:name], phone: order[:phone], content: content
    end
    {result: true}
  end

end