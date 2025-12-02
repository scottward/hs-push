#!/usr/bin/env ruby

require 'yaml'

puts "HabitStack Push - System Status"
puts "=" * 60

# Check editions
edition_files = Dir.glob('editions/*.md').sort
if edition_files.empty?
  puts "\n❌ No edition files found"
  puts "   Run: ruby scripts/csv_to_markdown.rb"
else
  puts "\n✓ Edition Files: #{edition_files.length} files"

  # Parse edition numbers from filename (e.g., "34-start-smart.md" -> 34)
  edition_numbers = edition_files.map do |file|
    basename = File.basename(file)
    if basename =~ /^(\d+)-/
      $1.to_i
    end
  end.compact.sort

  if edition_numbers.any?
    puts "  Range: Edition #{edition_numbers.min} to #{edition_numbers.max}"

    # Check for gaps
    gaps = []
    (edition_numbers.min..edition_numbers.max).each do |num|
      gaps << num unless edition_numbers.include?(num)
    end

    if gaps.any?
      puts "  ⚠️  Missing editions: #{gaps.join(', ')}"
    end
  end
end

# Check queued emails
queued_files = Dir.glob('queued/*.html').sort
puts "\n📧 Queued Emails: #{queued_files.length} files"
if queued_files.any?
  puts "  Files ready to schedule:"
  queued_files.each do |file|
    basename = File.basename(file)
    if basename =~ /^(\d{4}-\d{2}-\d{2})-(\d{4})-edition-(\d+)/
      date = $1
      time = $2
      edition = $3
      puts "    - Edition #{edition} → #{date} at #{time[0..1]}:#{time[2..3]}"
    else
      puts "    - #{basename}"
    end
  end
  puts "\n  Next: Review HTML files, then run schedule_emails.rb"
end

# Check sent emails
sent_files = Dir.glob('sent/*.html').sort
sent_test_files = Dir.glob('sent-test/*.html').sort
puts "\n✅ Sent Emails (Production): #{sent_files.length} files"
puts "✅ Sent Emails (Test): #{sent_test_files.length} files"

# Check logs
log_files = Dir.glob('logs/*.log').sort
puts "\n📋 Log Files: #{log_files.length} files"
if log_files.any?
  latest_log = log_files.last
  puts "  Latest: #{File.basename(latest_log)}"
  mtime = File.mtime(latest_log)
  puts "  Date: #{mtime.strftime('%Y-%m-%d %H:%M:%S')}"
end

# Check configuration
puts "\n⚙️  Configuration:"
if File.exist?('config.yaml')
  config = YAML.load_file('config.yaml')

  # Check production lists
  list_ids = config.dig('sendgrid', 'list_ids')
  segment_ids = config.dig('sendgrid', 'segment_ids')
  if list_ids && !list_ids.empty?
    puts "  ✓ Production lists: #{list_ids.length} list(s)"
  end
  if segment_ids && !segment_ids.empty?
    puts "  ✓ Production segments: #{segment_ids.length} segment(s)"
  end

  # Check test lists
  test_list_ids = config.dig('sendgrid', 'test_list_ids')
  test_segment_ids = config.dig('sendgrid', 'test_segment_ids')
  if test_list_ids && !test_list_ids.empty?
    puts "  ✓ Test lists: #{test_list_ids.length} list(s)"
  end
  if test_segment_ids && !test_segment_ids.empty?
    puts "  ✓ Test segments: #{test_segment_ids.length} segment(s)"
  end

  if (!list_ids || list_ids.empty?) && (!segment_ids || segment_ids.empty?)
    puts "  ⚠️  No production lists/segments configured"
  end
  if (!test_list_ids || test_list_ids.empty?) && (!test_segment_ids || test_segment_ids.empty?)
    puts "  ⚠️  No test lists/segments configured"
  end
else
  puts "  ❌ config.yaml not found"
end

if ENV['SENDGRID_API_KEY']
  key = ENV['SENDGRID_API_KEY']
  puts "  ✓ SENDGRID_API_KEY: #{key[0..8]}... (#{key.length} chars)"
else
  puts "  ⚠️  SENDGRID_API_KEY environment variable not set"
end

# Check dependencies
puts "\n📦 Dependencies:"
if File.exist?('Gemfile.lock')
  puts "  ✓ Gems installed (Gemfile.lock exists)"
else
  puts "  ⚠️  Gemfile.lock not found"
  puts "     Run: bundle install"
end

puts "\n" + "=" * 60
puts "Status check complete"
puts ""
