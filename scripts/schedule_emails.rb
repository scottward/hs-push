#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'
require 'yaml'
require 'date'
require 'time'
require 'fileutils'
require 'io/console'

# This script schedules queued HTML emails via SendGrid API
# It reads files from queued/, schedules them, and moves them to sent/ or sent-test/
#
# Usage:
#   ruby scripts/schedule_emails.rb           # Test mode (default)
#   ruby scripts/schedule_emails.rb --live    # Live mode (production lists)

# Parse command line arguments
live_mode = ARGV.include?('--live')

# Load configuration
config_path = 'config.yaml'
unless File.exist?(config_path)
  puts "Error: Configuration file not found: #{config_path}"
  exit 1
end

config = YAML.load_file(config_path)

# Get SendGrid API key - check environment or prompt
api_key = ENV['SENDGRID_API_KEY']
unless api_key
  puts "SendGrid API key not found in environment."
  print "Please enter your SendGrid API key: "
  api_key = STDIN.noecho(&:gets).chomp
  puts ""  # New line after hidden input

  unless api_key && !api_key.strip.empty?
    puts "Error: API key cannot be empty"
    exit 1
  end

  # Export it to the environment for this session
  ENV['SENDGRID_API_KEY'] = api_key
  puts "✓ API key set for this session"
  puts "  To make it permanent, run: echo 'export SENDGRID_API_KEY=\"your-key\"' >> ~/.bashrc"
  puts ""
end

# Display mode
puts "=" * 70
if live_mode
  puts "🔴 LIVE MODE - Sending to production lists"
  puts "=" * 70
else
  puts "🟢 TEST MODE - Sending to test lists"
  puts "=" * 70
end
puts ""

# Get list IDs based on mode
if live_mode
  list_ids = config.dig('sendgrid', 'list_ids')
  segment_ids = config.dig('sendgrid', 'segment_ids')
  sent_dir = 'sent'
else
  list_ids = config.dig('sendgrid', 'test_list_ids')
  segment_ids = config.dig('sendgrid', 'test_segment_ids')
  sent_dir = 'sent-test'
end

# Validate we have at least one destination
if (list_ids.nil? || list_ids.empty?) && (segment_ids.nil? || segment_ids.empty?)
  mode_name = live_mode ? "production" : "test"
  puts "Error: No #{mode_name} lists or segments configured in config.yaml"
  exit 1
end

# Get other configuration
sender_id = config.dig('sendgrid', 'sender_id')
suppression_group_id = config.dig('sendgrid', 'suppression_group_id')
name_prefix = config.dig('sendgrid', 'name_prefix') || 'HS Push - '
subject_prefix = config.dig('email', 'subject_prefix') || '🕗 Plan your week // '

# Show what we're sending to
puts "Sending to:"
puts "  Lists: #{list_ids.join(', ')}" if list_ids && !list_ids.empty?
puts "  Segments: #{segment_ids.join(', ')}" if segment_ids && !segment_ids.empty?
puts "  Sent folder: #{sent_dir}/"
puts ""

# Get all queued HTML files
queued_files = Dir.glob('queued/*.html').sort

if queued_files.empty?
  puts "No queued emails found in queued/ directory"
  puts "Run queue_emails.rb first to generate emails"
  exit 0
end

puts "Found #{queued_files.length} queued email(s)"
puts ""

# Parse file info for summary
file_info = queued_files.map do |f|
  fname = File.basename(f)
  if fname =~ /^(\d{4}-\d{2}-\d{2})-\d{4}-edition-(\d+)-/
    { date: $1, edition: $2.to_i, filename: fname }
  else
    { date: "unknown", edition: 0, filename: fname }
  end
end

first_date = file_info.first[:date]
last_date = file_info.last[:date]
editions = file_info.map { |f| f[:edition] }.sort

puts "  Date range: #{first_date} to #{last_date}"
puts "  Editions: #{editions.first}-#{editions.last} (#{editions.join(', ')})"
puts ""

# Confirmation prompt for live mode
if live_mode
  puts "=" * 60
  puts "⚠️  You are about to schedule #{queued_files.length} emails to PRODUCTION."
  puts "=" * 60
  print "Type 'yes' to continue: "
  confirmation = STDIN.gets.chomp
  unless confirmation.downcase == 'yes'
    puts "Aborted."
    exit 0
  end
  puts ""
end

puts "=" * 60

# Create log file
timestamp = Time.now.strftime('%Y-%m-%d_%H-%M-%S')
log_file = "logs/schedule_#{timestamp}.log"
log = File.open(log_file, 'w')
log.puts "SendGrid Scheduling Log - #{Time.now}"
log.puts "=" * 60
log.puts ""

scheduled_count = 0
failed_count = 0

queued_files.each do |html_file|
  filename = File.basename(html_file)
  puts "\nProcessing: #{filename}"
  log.puts "Processing: #{filename}"

  # Parse filename: YYYY-MM-DD-HHMM-edition-NN-subject.html
  if filename =~ /^(\d{4}-\d{2}-\d{2})-(\d{4})-edition-(\d+)-(.+)\.html$/
    date_str = $1
    time_str = $2
    edition_num = $3.to_i
    subject_slug = $4

    # Parse schedule time
    begin
      send_date = Date.parse(date_str)
      hour = time_str[0..1].to_i
      minute = time_str[2..3].to_i
      send_time = Time.new(send_date.year, send_date.month, send_date.day, hour, minute, 0)
      send_timestamp = send_time.to_i
    rescue => e
      puts "  Error: Failed to parse date/time from filename: #{e.message}"
      puts "  ⛔ Stopping due to error."
      log.puts "  ERROR: Failed to parse date/time: #{e.message}"
      failed_count += 1
      break
    end

    # Read HTML content
    html_content = File.read(html_file)

    # Find corresponding edition file to get subject
    edition_file = Dir.glob("editions/#{edition_num}-*.md").first
    unless edition_file
      puts "  Error: Edition file not found for edition #{edition_num}"
      puts "  ⛔ Stopping due to error."
      log.puts "  ERROR: Edition file not found"
      failed_count += 1
      break
    end

    # Read edition file to get subject suffix
    edition_content = File.read(edition_file)
    parts = edition_content.split(/^---\s*$/, 3)
    front_matter = YAML.load(parts[1])
    subject_suffix = front_matter['subject_suffix']

    # Build full subject line with prefix
    subject = "#{subject_prefix}#{subject_suffix}"

    # Build single send name: HS Push - #34 - Start Smart
    single_send_name = "#{name_prefix.strip} - ##{edition_num} - #{subject_suffix}"

    puts "  Edition: #{edition_num}"
    puts "  Subject: #{subject}"
    puts "  Name: #{single_send_name}"
    puts "  Scheduled for: #{send_time.strftime('%Y-%m-%d %H:%M %Z')}"

    log.puts "  Edition: #{edition_num}"
    log.puts "  Subject: #{subject}"
    log.puts "  Name: #{single_send_name}"
    log.puts "  Scheduled: #{send_time.strftime('%Y-%m-%d %H:%M %Z')}"

    begin
      # STEP 1: Create the Single Send
      # POST /v3/marketing/singlesends

      create_uri = URI.parse('https://api.sendgrid.com/v3/marketing/singlesends')
      http = Net::HTTP.new(create_uri.host, create_uri.port)
      http.use_ssl = true

      create_request = Net::HTTP::Post.new(create_uri.path, {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{api_key}"
      })

      # Build send_to configuration
      send_to = {}
      send_to[:list_ids] = list_ids if list_ids && !list_ids.empty?
      send_to[:segment_ids] = segment_ids if segment_ids && !segment_ids.empty?

      # Build Single Send payload (without send_at)
      create_payload = {
        name: single_send_name,
        send_to: send_to,
        email_config: {
          subject: subject,
          html_content: html_content,
          generate_plain_content: true,
          sender_id: sender_id,
          suppression_group_id: suppression_group_id
        }
      }

      # Remove nil values
      create_payload[:email_config].delete(:sender_id) if create_payload[:email_config][:sender_id].nil?
      create_payload[:email_config].delete(:suppression_group_id) if create_payload[:email_config][:suppression_group_id].nil?

      create_request.body = create_payload.to_json

      # Send the create request
      puts "  Creating Single Send..."
      log.puts "  Creating Single Send..."
      create_response = http.request(create_request)

      unless create_response.code.to_i >= 200 && create_response.code.to_i < 300
        puts "  ✗ Failed to create: HTTP #{create_response.code}"
        puts "  Response: #{create_response.body}"
        puts "  ⛔ Stopping due to error."
        log.puts "  FAILED TO CREATE: HTTP #{create_response.code}"
        log.puts "  Response: #{create_response.body}"
        failed_count += 1
        break
      end

      # Parse the response to get the single send ID
      create_result = JSON.parse(create_response.body)
      single_send_id = create_result['id']

      puts "  ✓ Created Single Send ID: #{single_send_id}"
      log.puts "  Created Single Send ID: #{single_send_id}"

      # STEP 2: Schedule the Single Send
      # PUT /v3/marketing/singlesends/{id}/schedule

      schedule_uri = URI.parse("https://api.sendgrid.com/v3/marketing/singlesends/#{single_send_id}/schedule")
      schedule_request = Net::HTTP::Put.new(schedule_uri.path, {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{api_key}"
      })

      schedule_payload = {
        send_at: send_time.utc.iso8601  # ISO 8601 format
      }

      schedule_request.body = schedule_payload.to_json

      # Send the schedule request
      puts "  Scheduling for #{send_time.utc.iso8601}..."
      log.puts "  Scheduling for #{send_time.utc.iso8601}..."
      response = http.request(schedule_request)

      if response.code.to_i >= 200 && response.code.to_i < 300
        puts "  ✓ Successfully scheduled!"
        log.puts "  SUCCESS: HTTP #{response.code}"
        log.puts "  Response: #{response.body}" if response.body && !response.body.empty?

        # Move or copy file to appropriate sent directory
        sent_path = "#{sent_dir}/#{filename}"
        if live_mode
          FileUtils.mv(html_file, sent_path)
          puts "  Moved to: #{sent_path}"
          log.puts "  Moved to: #{sent_path}"
        else
          FileUtils.cp(html_file, sent_path)
          puts "  Copied to: #{sent_path} (original remains in queued/)"
          log.puts "  Copied to: #{sent_path}"
        end

        # Update last_sent_at in edition file (surgical replacement to preserve formatting)
        edition_content = File.read(edition_file)
        new_timestamp = send_time.strftime('%Y-%m-%d %H:%M:%S %Z')

        if edition_content =~ /^last_sent_at:.*$/
          # Replace existing last_sent_at line
          updated_content = edition_content.gsub(/^last_sent_at:.*$/, "last_sent_at: '#{new_timestamp}'")
        else
          # Add last_sent_at after subject_suffix line
          updated_content = edition_content.gsub(/^(subject_suffix:.*)$/, "\\1\nlast_sent_at: '#{new_timestamp}'")
        end

        File.write(edition_file, updated_content)
        puts "  Updated last_sent_at in #{File.basename(edition_file)}"
        log.puts "  Updated edition file"

        scheduled_count += 1

        # Delay between requests to avoid overwhelming SendGrid API
        sleep(2)
      else
        puts "  ✗ Failed to schedule: HTTP #{response.code}"
        puts "  Response: #{response.body}"
        puts "  ⛔ Stopping due to error."
        log.puts "  FAILED: HTTP #{response.code}"
        log.puts "  Response: #{response.body}"
        failed_count += 1
        break
      end

    rescue => e
      puts "  ✗ Error: #{e.message}"
      puts "  #{e.backtrace.first}"
      puts "  ⛔ Stopping due to error."
      log.puts "  ERROR: #{e.message}"
      log.puts "  #{e.backtrace.join("\n  ")}"
      failed_count += 1
      break
    end

  else
    puts "  Error: Invalid filename format"
    puts "  ⛔ Stopping due to error."
    log.puts "  ERROR: Invalid filename format"
    failed_count += 1
    break
  end

  log.puts ""
end

log.puts ""
log.puts "=" * 60
if failed_count > 0
  log.puts "Stopped due to failure!"
  log.puts "Successfully scheduled: #{scheduled_count}"
  log.puts "Failed: #{failed_count}"
  log.puts "Remaining: #{queued_files.length - scheduled_count - failed_count}"
else
  log.puts "Scheduling complete!"
  log.puts "Successfully scheduled: #{scheduled_count}"
end
log.puts "=" * 60
log.close

puts ""
puts "=" * 60
if failed_count > 0
  puts "⛔ Stopped due to failure!"
  puts "Successfully scheduled: #{scheduled_count}"
  puts "Failed: #{failed_count}"
  puts "Remaining: #{queued_files.length - scheduled_count - failed_count}"
else
  puts "Scheduling complete!"
  puts "Successfully scheduled: #{scheduled_count}"
end
puts ""
puts "Log saved to: #{log_file}"
puts ""
puts "IMPORTANT: Verify the scheduled emails in your SendGrid dashboard"
puts "SendGrid URL: https://app.sendgrid.com/marketing/singleSends"
puts "=" * 60
