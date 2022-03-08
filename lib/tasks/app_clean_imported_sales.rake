namespace :app do
  desc "Clean imported sales"
  task clean_imported_sales: :environment do
    log = Logger.new("log/clean_imported_sales.log")
    log.info ImportedSale.count

    ActiveRecord::Base.uncached do
      ImportedSale.find_each do |sale|
        log.info "[#{sale.sold_at}] {#{sale.imei}} #{sale.serial_number}"

        repeats = ImportedSale.where.not(id: sale.id).where(
          serial_number: sale.serial_number,
          imei: sale.imei,
          sold_at: sale.sold_at,
          quantity: sale.quantity
        )

        if repeats.any?
          log.info repeats.delete_all
        end
      end
    end

    log.info ImportedSale.count
    log.close
  end
end
