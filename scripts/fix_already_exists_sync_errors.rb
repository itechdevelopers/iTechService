#!/usr/bin/env ruby

# Script to fix sync records that failed with "already exists" error
# by checking their actual status in 1C and updating them accordingly

require_relative '../config/environment'

class FixAlreadyExistsSyncErrors
  ERROR_MESSAGE_PATTERN = 'не удалось загрузить по причине: уже существует в базе'
  DAYS_TO_CHECK = 4
  
  def initialize(dry_run: true)
    @dry_run = dry_run
    @client = OrderClient.new
    @processed_count = 0
    @fixed_count = 0
    @errors = []
  end
  
  def run
    puts "🔍 Fix Already Exists Sync Errors Script"
    puts "Mode: #{@dry_run ? 'DRY RUN (no changes will be made)' : 'LIVE RUN (changes will be applied)'}"
    puts "Checking records from the last #{DAYS_TO_CHECK} days..."
    puts "-" * 60
    
    # Find affected sync records
    affected_records = find_affected_records
    
    if affected_records.empty?
      puts "✅ No records found with 'already exists' error in the last #{DAYS_TO_CHECK} days."
      return
    end
    
    puts "📋 Found #{affected_records.count} sync records with 'already exists' error:"
    puts
    
    # Process each record
    affected_records.each do |sync_record|
      process_sync_record(sync_record)
    end
    
    # Summary
    puts
    puts "=" * 60
    puts "📊 SUMMARY:"
    puts "  Total processed: #{@processed_count}"
    puts "  Successfully fixed: #{@fixed_count}"
    puts "  Errors encountered: #{@errors.count}"
    
    if @errors.any?
      puts
      puts "⚠️  ERRORS:"
      @errors.each { |error| puts "  - #{error}" }
    end
    
    if @dry_run && @fixed_count > 0
      puts
      puts "ℹ️  This was a dry run. To apply changes, run with: dry_run: false"
    end
  end
  
  private
  
  def find_affected_records
    # Find sync records from the last 4 days with the specific error
    OrderExternalSync
      .where(external_system: :one_c)
      .where(sync_status: [:failed, :permanently_failed])
      .where('last_attempt_at >= ?', DAYS_TO_CHECK.days.ago)
      .where('last_error ILIKE ?', "%#{ERROR_MESSAGE_PATTERN}%")
      .includes(:order)
      .order(:last_attempt_at)
  end
  
  def process_sync_record(sync_record)
    @processed_count += 1
    order = sync_record.order
    
    puts "[#{@processed_count}] Order ##{order.number} (ID: #{order.id})"
    puts "    Sync Status: #{sync_record.sync_status}"
    puts "    Last Error: #{sync_record.last_error.truncate(80)}"
    puts "    Last Attempt: #{sync_record.last_attempt_at}"
    
    begin
      # Check status in 1C
      puts "    🔍 Checking status in 1C..."
      result = @client.check_order_status(order.number)
      
      if !result[:success]
        error_msg = "Failed to check 1C status: #{result[:error]}"
        puts "    ❌ #{error_msg}"
        @errors << "Order ##{order.number}: #{error_msg}"
        return
      end
      
      data = result[:data]
      puts "    📄 1C Response: #{data.inspect}"
      
      # Check if order exists in 1C with valid external_number
      if can_fix_sync_record?(data)
        external_number = data['external_number']
        puts "    ✅ Order found in 1C with external_number: #{external_number}"
        
        if @dry_run
          puts "    🔧 [DRY RUN] Would mark as synced with external_id: #{external_number}"
          @fixed_count += 1
        else
          puts "    🔧 Marking as synced with external_id: #{external_number}"
          sync_record.mark_sync_success!(external_number)
          @fixed_count += 1
          puts "    ✅ Successfully updated sync record"
        end
      else
        reason = get_skip_reason(data)
        puts "    ⏭️  Skipping: #{reason}"
      end
      
    rescue => e
      error_msg = "Unexpected error: #{e.message}"
      puts "    ❌ #{error_msg}"
      @errors << "Order ##{order.number}: #{error_msg}"
    end
    
    puts
  end
  
  def can_fix_sync_record?(data)
    data.is_a?(Hash) &&
      data['status'] == 'found' &&
      data['deleted'] == false &&
      data['external_number'].present?
  end
  
  def get_skip_reason(data)
    return "Invalid response format" unless data.is_a?(Hash)
    return "Order not found in 1C" unless data['status'] == 'found'
    return "Order is deleted in 1C" if data['deleted'] == true
    return "No external_number in response" unless data['external_number'].present?
    "Unknown reason"
  end
end

# Command line interface
if __FILE__ == $0
  dry_run = ARGV.include?('--dry-run') || !ARGV.include?('--apply')
  
  if !dry_run
    puts "⚠️  This will make actual changes to the database."
    print "Are you sure you want to continue? (y/N): "
    response = gets.chomp.downcase
    exit unless response == 'y' || response == 'yes'
  end
  
  fixer = FixAlreadyExistsSyncErrors.new(dry_run: dry_run)
  fixer.run
end