class BarcodeApi < Grape::API
  version 'v1', using: :path

  before { authenticate! }

  desc 'Scan barcode'
  get '/scan/:barcode_num', requirements: { barcode_num: /[0-9]*/ } do
    barcode_num = params[:barcode_num]
    #if barcode_num.start_with? Product::BARCODE_PREFIX
    #  if (item = Item.find_by_barcode_num barcode_num).present?
    #    render json: {product: item}
    #  else
    #    render status: 403, json: {error: t('errors.nothing_found')}
    #  end
    #else
      barcode_num = barcode_num.gsub(/^0+/, '').chop if barcode_num.length == 13
      if (service_job = ServiceJob.find_by_ticket_number(barcode_num)).present?
        #present service_job
        {service_job: service_job}
      else
        error!({error: I18n.t('errors.nothing_found')}, 404)
      end
    #end
  end
end