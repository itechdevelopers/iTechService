class PrintReceipt
  attr_accessor :sale

  def initialize(department, params)
    @sale = OpenStruct.new.tap do |sale|
      sale.id = params[:number]
      sale.number = params[:number]
      sale.seller = params[:seller]
      sale.department = department
      sale.cash_shift_id = department.current_cash_shift.id
      sale.date = params[:date].to_datetime.in_time_zone
      sale.customer = params[:customer]
      sale.seller_post = params[:seller_post]
      sale.sum = params[:sum]
      sale.sum_in_words = params[:sum_in_words]
      sale.payments = [OpenStruct.new(kind: 'cash', value: params[:sum])]
      sale.sale_items = params[:products].collect do |index, product|
        attributes = {
          warranty_term: product[:warranty_term].to_i,
          feature_accounting: product[:serial_number].present?,
          features: [OpenStruct.new(value: product[:serial_number]), OpenStruct.new(value: product[:imei])],
          code: product[:article],
          name: product[:name],
          quantity: product[:quantity].to_i,
          measure: product[:measure],
          price: product[:price].to_i,
          serial_number: product[:serial_number],
          imei: product[:imei]
        }
        OpenStruct.new attributes
      end
    end
  end

  def call
    self
  end

  def self.call(department, params)
    new(department, params).call
  end

  def receipt
    @receipt ||= make_receipt
  end

  def warranty
    @warranty ||= make_warranty
  end

  def sale_check
    @sale_check ||= make_sale_check
  end

  private

  def make_receipt
    ReceiptPdf.new(sale)
  end

  def make_warranty
    WarrantyPdf.new(sale)
  end

  def make_sale_check
    ManualSaleCheckPdf.new(sale)
  end
end
