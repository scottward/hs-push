#!/usr/bin/env ruby

require 'kramdown'
require 'yaml'
require 'date'
require 'optparse'

# This script generates HTML email files from markdown edition files
# and queues them for sending with scheduled dates/times
#
# Usage: ruby scripts/queue_emails.rb --start N --end M --start-date YYYY-MM-DD --start-time HHMM

# Parse command line arguments
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: queue_emails.rb [options]"

  opts.on("--start N", Integer, "Starting edition number (required)") do |n|
    options[:start] = n
  end

  opts.on("--end M", Integer, "Ending edition number (required)") do |m|
    options[:end] = m
  end

  opts.on("--start-date DATE", String, "Start date YYYY-MM-DD (required)") do |date|
    options[:start_date] = date
  end

  opts.on("--start-time TIME", String, "Start time HHMM (required)") do |time|
    options[:start_time] = time
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

# Validate required arguments
unless options[:start] && options[:end] && options[:start_date] && options[:start_time]
  puts "Error: Missing required arguments"
  puts "Usage: ruby scripts/queue_emails.rb --start N --end M --start-date YYYY-MM-DD --start-time HHMM"
  puts ""
  puts "Example: ruby scripts/queue_emails.rb --start 35 --end 40 --start-date 2025-11-17 --start-time 0800"
  exit 1
end

# Validate date format
begin
  start_date = Date.parse(options[:start_date])
rescue ArgumentError
  puts "Error: Invalid date format. Use YYYY-MM-DD"
  exit 1
end

# Validate time format
unless options[:start_time] =~ /^\d{4}$/
  puts "Error: Invalid time format. Use HHMM (e.g., 0800 for 8:00 AM)"
  exit 1
end

# Load the HTML template
template_path = 'template.html'
unless File.exist?(template_path)
  puts "Error: Template file not found: #{template_path}"
  exit 1
end

template = File.read(template_path)

puts "Queueing emails for editions #{options[:start]} to #{options[:end]}"
puts "Starting: #{options[:start_date]} at #{options[:start_time]}"
puts ""

queued_count = 0
current_date = start_date

(options[:start]..options[:end]).each do |edition_num|
  # Find the edition file (try different filename formats)
  edition_files = Dir.glob("editions/edition-#{edition_num.to_s.rjust(2, '0')}-*.md")

  unless edition_files.length > 0
    puts "Warning: Edition file not found for edition #{edition_num}"
    next
  end

  edition_file = edition_files.first
  puts "Processing: #{edition_file}"

  # Read and parse the markdown file
  content = File.read(edition_file)

  # Split front matter from content
  parts = content.split(/^---\s*$/, 3)
  if parts.length < 3
    puts "Error: Invalid markdown format in #{edition_file}"
    next
  end

  # Parse YAML front matter
  begin
    front_matter = YAML.load(parts[1])
  rescue => e
    puts "Error parsing YAML in #{edition_file}: #{e.message}"
    next
  end

  # Extract the email content section
  markdown_content = parts[2]
  if markdown_content =~ /## Email Content\s*\n(.*?)\n## Post Text/m
    email_markdown = $1.strip
  else
    puts "Error: Could not find Email Content section in #{edition_file}"
    next
  end

  # Validate required fields
  required_fields = ['quote_text', 'quote_author', 'hosted_cartoon_url', 'subject_suffix', 'edition_number']
  missing_fields = required_fields.select { |field| !front_matter[field] || front_matter[field].to_s.strip.empty? }

  if missing_fields.length > 0
    puts "Error: Missing required fields in #{edition_file}: #{missing_fields.join(', ')}"
    next
  end

  # Convert markdown to HTML
  coaching_html = Kramdown::Document.new(email_markdown).to_html

  # Replace placeholders in template
  html_output = template.dup
  html_output.gsub!('{{quote_text}}', front_matter['quote_text'])
  html_output.gsub!('{{quote_author}}', front_matter['quote_author'])
  html_output.gsub!('{{coaching_html}}', coaching_html)
  html_output.gsub!('{{hosted_cartoon_url}}', front_matter['hosted_cartoon_url'])
  html_output.gsub!('{{edition_number}}', front_matter['edition_number'].to_s)

  # Generate output filename with scheduled date/time
  date_str = current_date.strftime('%Y-%m-%d')
  filename_suffix = front_matter['subject_suffix'].downcase.gsub(/[^a-z0-9\s-]/, '').gsub(/\s+/, '-')
  output_filename = "queued/#{date_str}-#{options[:start_time]}-edition-#{edition_num.to_s.rjust(2, '0')}-#{filename_suffix}.html"

  # Write the HTML file
  File.write(output_filename, html_output)

  puts "  → Queued: #{output_filename}"
  puts "     Scheduled for: #{date_str} at #{options[:start_time][0..1]}:#{options[:start_time][2..3]}"

  queued_count += 1

  # Increment date by 7 days for next edition
  current_date += 7
end

puts ""
puts "=" * 60
puts "Queueing complete!"
puts "Queued #{queued_count} email(s) to the queued/ directory"
puts ""
puts "Next steps:"
puts "1. Review the HTML files in queued/ to verify content"
puts "2. Run: ruby scripts/schedule_queued_emails.rb"
puts "   This will schedule the emails via SendGrid API"
puts "=" * 60
