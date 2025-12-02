#!/usr/bin/env ruby

require 'csv'
require 'reverse_markdown'
require 'yaml'
require 'date'

# This script imports edition data from the Monday/Zapier CSV export
# and creates markdown files for editions that don't already exist
# Usage: ruby scripts/csv_to_markdown.rb [csv_filename]

csv_file = ARGV[0] || 'monday_emails_2025-11-15T00_34_16.csv'

unless File.exist?(csv_file)
  puts "Error: CSV file not found: #{csv_file}"
  puts "Usage: ruby scripts/csv_to_markdown.rb [csv_filename]"
  exit 1
end

puts "Reading CSV file: #{csv_file}"

created_count = 0
skipped_count = 0

CSV.foreach(csv_file, headers: true) do |row|
  begin
    # Extract data from CSV
    edition_number = row['edition_number']&.to_i
    next unless edition_number && edition_number > 0

    quote_text = row['quote_text']
    quote_author = row['quote_author']
    coaching_html = row['coaching_html']
    subject_suffix = row['subject_suffix']
    andertoon_number = row['andertoon_number']&.to_i
    cartoon_url = row['hosted_cartoon_url']
    send_at = row['send_at']
    post_text_raw = row['post']

    # Skip if missing essential fields
    unless quote_text && quote_author && coaching_html && subject_suffix && cartoon_url
      puts "Skipping edition #{edition_number} - missing essential fields"
      next
    end

    # Generate filename (edition number derived from filename, no "edition-" prefix)
    filename_suffix = subject_suffix.downcase.gsub(/[^a-z0-9\s-]/, '').gsub(/\s+/, '-')
    filename = "editions/#{edition_number}-#{filename_suffix}.md"

    # Skip if file already exists (from .eml extraction)
    if File.exist?(filename)
      puts "Skipping edition #{edition_number} - file already exists: #{filename}"
      skipped_count += 1
      next
    end

    # Convert coaching HTML to markdown
    coaching_markdown = ReverseMarkdown.convert(coaching_html, unknown_tags: :bypass)

    # Use the post text from CSV if available, otherwise generate it
    if post_text_raw && !post_text_raw.strip.empty?
      post_text = post_text_raw.strip
    else
      # Generate post text from quote and coaching
      post_text = "\"#{quote_text}\"\n— #{quote_author}\n\n"
      plain_coaching = coaching_html.gsub(/<[^>]+>/, ' ')
                                     .gsub(/\s+/, ' ')
                                     .gsub('&rsquo;', "'")
                                     .gsub('&#39;', "'")
                                     .gsub('&quot;', '"')
                                     .gsub('&amp;', '&')
                                     .strip
      post_text += plain_coaching
    end

    # Parse feedback if present
    feedback = row['Feedback']&.strip || ""

    # Create YAML front matter (edition_number derived from filename)
    front_matter = {
      'quote_text' => quote_text,
      'quote_author' => quote_author,
      'subject_suffix' => subject_suffix,
      'hosted_cartoon_url' => cartoon_url
    }

    # Add andertoon_number if present
    if andertoon_number && andertoon_number > 0
      front_matter['andertoon_number'] = andertoon_number
    else
      front_matter['andertoon_number'] = 'TODO'
    end

    # Add last_sent_at if the email was sent
    if send_at && !send_at.strip.empty?
      begin
        sent_time = DateTime.parse(send_at)
        front_matter['last_sent_at'] = sent_time.to_s
      rescue
        # If parsing fails, just skip the last_sent_at field
      end
    end

    # Write the markdown file
    File.open(filename, 'w') do |f|
      f.puts front_matter.to_yaml
      f.puts "---"
      f.puts
      f.puts "## Email Content"
      f.puts
      f.puts coaching_markdown
      f.puts
      f.puts "## Post Text"
      f.puts
      f.puts post_text
      f.puts
      f.puts "## Feedback"
      f.puts
      f.puts feedback
    end

    puts "Created: #{filename}"
    created_count += 1

  rescue => e
    puts "Error processing row: #{e.message}"
    puts "Row data: #{row.inspect}"
    next
  end
end

puts "\nProcessing complete!"
puts "Created: #{created_count} edition files"
puts "Skipped: #{skipped_count} edition files (already exist)"

if created_count > 0
  puts "\nNOTE: Check for any 'andertoon_number' fields set to 'TODO' and update them manually"
end
