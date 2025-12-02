#!/usr/bin/env ruby

require 'yaml'
require 'date'

# This script lists all edition files with their metadata

edition_files = Dir.glob('editions/*.md').sort

if edition_files.empty?
  puts "No edition files found in editions/ directory"
  puts "Run: ruby scripts/csv_to_markdown.rb"
  exit 0
end

puts "HabitStack Push - Edition List"
puts "=" * 80

edition_files.each do |file|
  begin
    content = File.read(file)
    parts = content.split(/^---\s*$/, 3)

    if parts.length < 3
      puts "⚠️  #{File.basename(file)} - Invalid format (no YAML front matter)"
      next
    end

    front_matter = YAML.load(parts[1])

    # Extract edition number from filename (e.g., "34-start-smart.md" -> 34)
    basename = File.basename(file)
    edition_num = basename.match(/^(\d+)-/)[1].to_i rescue nil
    subject = front_matter['subject_suffix']
    sent_at = front_matter['last_sent_at']
    andertoon = front_matter['andertoon_number']

    # Format output
    status = sent_at ? "✅ SENT" : "📝 Draft"
    andertoon_status = (andertoon == 'TODO' || andertoon.nil?) ? "⚠️  TODO" : "✓"

    puts ""
    puts "Edition #{edition_num}: #{subject}"
    puts "  Status: #{status}"
    if sent_at
      begin
        sent_date = DateTime.parse(sent_at.to_s)
        puts "  Sent: #{sent_date.strftime('%Y-%m-%d %H:%M')}"
      rescue
        puts "  Sent: #{sent_at}"
      end
    end
    puts "  Andertoon: #{andertoon_status} #{andertoon}"
    puts "  File: #{File.basename(file)}"

  rescue => e
    puts "❌ #{File.basename(file)} - Error: #{e.message}"
  end
end

puts ""
puts "=" * 80
puts "Total: #{edition_files.length} edition(s)"
puts ""
