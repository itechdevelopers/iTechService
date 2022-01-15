class SalesImportJob < ApplicationJob
  queue_as :critical
  attr_accessor :import_logs, :logs_file

  def perform(file = nil)
    file ||= fetch_file
    return if file.nil?

    ImportedSale.uncached { import_sales file }
    ImportMailer.sales_import_log(import_logs).deliver_now
  end

  private

  RGXP_PRODUCT_CODE_AND_NAME = Regexp.new('(\d+) \| (.+)')
  RGXP_PRODUCT_CODE = Regexp.new('\d+')
  RGXP_PRODUCT_NAME = Regexp.new('.+')
  RGXP_SERIAL_NUMBER = Regexp.new('\A(\w+),?\Z')
  RGXP_SERIAL_NUMBER_IMEI = Regexp.new('(\w+), *(\d+)')
  RGXP_DATETIME = Regexp.new('(\d{2}.\d{2}.\d{4}\ \d{,2}:\d{2}:\d{2})')
  RGXP_DATE = Regexp.new('(\d{2}\.\d{2}\.\d{4})')

  def import_sales(file)
    sheet = FileLoader.open_spreadsheet(file)
    log :info, "Import started at #{Time.current.strftime('%Y.%m.%d %H:%M:%S')}"
    code_1c = device_type_s = sn = imei = date = qty = nil
    device_type = nil
    11.upto sheet.last_row-1 do |r|
      row = sheet.row r
      log :inverse, "#{r} #{'-'*140}"
      case row_type row[0], row[2]
      when :device_type
        code_1c = row[0]
        device_type_s = row[2]
        unless (device_type = DeviceType.find_by(code_1c: code_1c)).present?
          log :important, "Device type '#{device_type_s}' [#{code_1c}] not found!!!"
        end
      when :device_1
        sn = RGXP_SERIAL_NUMBER.match(row[0])[1]
        imei = nil
        log :info, row[0]
      when :device_2
        sn = RGXP_SERIAL_NUMBER_IMEI.match(row[0])[1]
        imei = RGXP_SERIAL_NUMBER_IMEI.match(row[0])[2]
        log :info, row[0]
      when :date
        date = RGXP_DATE.match(row[0])[1]
        qty = row[11]
        sold_at = "#{date} 00:00:00 +1000".to_time(:utc)
        sale = ImportedSale.find_or_initialize_by serial_number: sn,
                                                  imei: imei,
                                                  sold_at: sold_at,
                                                  device_type_id: device_type.try(:id),
                                                  quantity: qty

        if sale.new_record?
          if sale.save
            log :success, "New sale #{device_type.try(:full_name)} [#{sale.serial_number}] sold_at: #{sale_date(sale)}"
          else
            log :error, "Unable to save #{sale.inspect}: #{sale.errors.full_messages.join('. ')}"
          end
        else
          log :info, "Existing sale #{device_type.try(:full_name)} [#{sale.serial_number}] sold_at: #{sale_date(sale)}"
        end
      end
    end
    log :inverse, '-'*160
  end

  def row_type(val1, val2)
    if val2.present?
      :device_type
    elsif RGXP_SERIAL_NUMBER_IMEI === val1
      :device_2
    elsif RGXP_SERIAL_NUMBER === val1
      :device_1
    elsif RGXP_DATE === val1
      :date
    else
      nil
    end
  end

  def log(tag, string)
    import_logs << [tag.to_s, string]
    logs_file.puts "[#{tag.to_s.upcase}] #{string}"
  end

  def import_logs
    @import_logs ||= []
  end

  def logs_file
    @logs_file ||= File.new(Rails.root.join('log', "sales_import-#{Time.current.to_s(:number)}.log"), 'w')
  end

  def sale_date(sale)
    sale.sold_at.strftime('%d.%m.%Y')
  end

  def fetch_file
    status, result = FetchSalesFile.()
    return result if status

    ImportMailer.sales_import_error(result).deliver_now
    raise result
  end
end
