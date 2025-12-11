namespace :wiki do
  desc 'Migrate WikiPage images from local storage to WikiDocument (cloud storage)'
  task migrate_images: :environment do
    total = 0
    migrated = 0
    failed = 0

    pages_with_images = WikiPage.where.not(images: [])
    puts "Found #{pages_with_images.count} wiki pages with images"

    pages_with_images.find_each do |page|
      puts "\nProcessing WikiPage ##{page.id}: #{page.title}"

      page.images.each_with_index do |image, index|
        total += 1

        begin
          local_path = Rails.root.join('public', image.url.sub(%r{^/}, ''))

          unless File.exist?(local_path)
            puts "  [SKIP] Image #{index + 1} - file not found: #{local_path}"
            failed += 1
            next
          end

          document = page.documents.build
          document.file = File.open(local_path)

          if document.save
            puts "  [OK] Image #{index + 1} migrated: #{File.basename(local_path)}"
            migrated += 1
          else
            puts "  [FAIL] Image #{index + 1} - #{document.errors.full_messages.join(', ')}"
            failed += 1
          end
        rescue StandardError => e
          puts "  [ERROR] Image #{index + 1} - #{e.message}"
          failed += 1
        end
      end
    end

    puts "\n#{'=' * 40}"
    puts "Migration Summary"
    puts "#{'=' * 40}"
    puts "Total images:  #{total}"
    puts "Migrated:      #{migrated}"
    puts "Failed/Skipped: #{failed}"
    puts "#{'=' * 40}"
  end

  desc 'Clear old images from WikiPage after successful migration (RUN WITH CAUTION)'
  task clear_old_images: :environment do
    puts 'WARNING: This will clear all WikiPage.images data!'
    puts 'Make sure migration was successful before running this.'
    puts 'Press Ctrl+C to cancel, or wait 10 seconds to continue...'
    sleep 10

    cleared = 0
    WikiPage.where.not(images: []).find_each do |page|
      old_count = page.images.count
      page.update_column(:images, [])
      puts "Cleared #{old_count} images from WikiPage ##{page.id}: #{page.title}"
      cleared += old_count
    end

    puts "\nCleared #{cleared} images total."
    puts 'Old image files in public/uploads/wiki_page can be manually removed.'
  end
end
