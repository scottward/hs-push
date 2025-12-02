#!/usr/bin/env ruby

require 'mail'
require 'reverse_markdown'
require 'date'
require 'yaml'

# This script extracts weekly push emails from the EML file for specific Monday dates
# Usage: ruby scripts/extract_monday_emails.rb --start-edition N
#
# Extracts emails from Jan 6, 2025 through Sep 29, 2025 (every Monday)

# Parse command line arguments
start_edition = nil
ARGV.each_with_index do |arg, i|
  if arg == '--start-edition' && ARGV[i + 1]
    start_edition = ARGV[i + 1].to_i
  end
end

unless start_edition
  puts "Usage: ruby scripts/extract_monday_emails.rb --start-edition N"
  puts ""
  puts "This script extracts weekly push emails sent on Mondays from"
  puts "January 6, 2025 through September 29, 2025."
  puts ""
  puts "Please specify the edition number for the January 6, 2025 email."
  exit 1
end

# Generate list of Monday dates from Jan 6, 2025 to Sep 29, 2025
target_mondays = []
current_date = Date.new(2025, 1, 6)
end_date = Date.new(2025, 9, 29)

while current_date <= end_date
  target_mondays << current_date
  current_date += 7
end

puts "Looking for #{target_mondays.length} Monday emails"
puts "Date range: #{target_mondays.first} to #{target_mondays.last}"
puts "Starting edition number: #{start_edition}"
puts ""

# Read the EML file
eml_path = 'sources/all emails sent.eml'
unless File.exist?(eml_path)
  puts "Error: EML file not found: #{eml_path}"
  exit 1
end

puts "Reading EML file..."
eml_content = File.read(eml_path)

# Split the file into individual messages
messages = []
current_message = ""
in_message = false

eml_content.each_line do |line|
  if line =~ /^Delivered-To:/
    if !current_message.empty?
      messages << current_message
    end
    current_message = line
    in_message = true
  elsif in_message
    current_message << line
  end
end
messages << current_message if !current_message.empty?

puts "Found #{messages.length} embedded email messages"

# Build a hash of emails by date (keeping only one per date, preferring "Plan your week" subjects)
emails_by_date = {}

messages.each do |message_text|
  begin
    mail = Mail.read_from_string(message_text)
    next unless mail.date && mail.subject

    # Check if this is a HabitStack Push email
    subject = mail.subject.to_s
    next unless subject.include?('Plan your week')

    email_date = mail.date.to_date

    # Only keep if it's one of our target Mondays
    next unless target_mondays.include?(email_date)

    # Store the message (if we already have one for this date, keep the first one)
    emails_by_date[email_date] ||= { mail: mail, message: message_text }

  rescue => e
    # Skip problematic messages
    next
  end
end

puts "Found #{emails_by_date.length} matching Monday emails"
puts ""

# Process emails in chronological order
edition_number = start_edition
created_count = 0
skipped_count = 0

target_mondays.each do |monday_date|
  email_data = emails_by_date[monday_date]

  unless email_data
    puts "Warning: No email found for #{monday_date}"
    edition_number += 1
    next
  end

  mail = email_data[:mail]
  message_text = email_data[:message]

  begin
    # Extract subject suffix
    subject = mail.subject.to_s
    # Remove "🕗 Plan your week // " prefix and any trailing emoji
    subject_suffix = subject.gsub(/^.*?\/\/\s*/, '').strip
    subject_suffix = subject_suffix.gsub(/\s*[^\w\s.!?'",()-]+\s*$/, '').strip

    # Get the HTML part
    html_part = nil
    if mail.multipart?
      mail.parts.each do |part|
        if part.content_type =~ /text\/html/
          html_part = part.decoded
          break
        elsif part.multipart?
          part.parts.each do |subpart|
            if subpart.content_type =~ /text\/html/
              html_part = subpart.decoded
              break
            end
          end
        end
      end
    else
      html_part = mail.decoded if mail.content_type =~ /html/
    end

    unless html_part
      puts "Warning: No HTML content for #{monday_date} - skipping"
      edition_number += 1
      next
    end

    # Extract quote text and author from HTML
    quote_text = nil
    quote_author = nil

    # Pattern: <h2>The Quote</h2> ... <span>"quote"</span> ... <span><em>— Author</em></span>
    if html_part =~ /<h2[^>]*>The Quote<\/h2>.*?<span[^>]*>\s*[""]?([^<]+?)[""]?\s*<\/span>.*?<span[^>]*>.*?<em>([^<]+)<\/em>/m
      quote_text = $1&.strip&.gsub(/\s+/, ' ')&.gsub(/^[""]|[""]$/, '')
      quote_author = $2&.strip&.gsub(/^—\s*/, '')&.gsub(/\s+/, ' ')
    end

    # Extract coaching HTML
    coaching_html = nil
    if html_part =~ /<h2[^>]*>The Coaching<\/h2>(.*?)<h2[^>]*>The Smile<\/h2>/m
      coaching_html = $1.strip
    end

    # Extract cartoon URL
    cartoon_url = nil
    if html_part =~ /<img[^>]*src=["']([^"']*mcauto-images[^"']*)/
      cartoon_url = $1.gsub(/=\s*\n/, '').gsub(/\s+/, '')
    end

    # Skip if missing essential data
    unless quote_text && coaching_html && cartoon_url
      puts "Warning: Missing data for #{monday_date} (quote: #{!!quote_text}, coaching: #{!!coaching_html}, cartoon: #{!!cartoon_url})"
      edition_number += 1
      next
    end

    # Generate filename (edition number derived from filename, no "edition-" prefix)
    filename_suffix = subject_suffix.downcase.gsub(/[^a-z0-9\s-]/, '').gsub(/\s+/, '-').gsub(/-+$/, '')
    filename = "editions/#{edition_number}-#{filename_suffix}.md"

    # Skip if file already exists
    if File.exist?(filename)
      puts "Skipping edition #{edition_number} (#{monday_date}) - file exists: #{filename}"
      skipped_count += 1
      edition_number += 1
      next
    end

    # Convert coaching HTML to markdown
    coaching_markdown = ReverseMarkdown.convert(coaching_html, unknown_tags: :bypass)

    # Clean up HTML entities in quote
    quote_text = quote_text.gsub('&rsquo;', "'").gsub('&#39;', "'").gsub('&quot;', '"').gsub('&amp;', '&').gsub('&nbsp;', ' ')

    # Generate post text
    post_text = "\"#{quote_text}\"\n— #{quote_author}\n\n"
    plain_coaching = coaching_html.gsub(/<[^>]+>/, ' ')
                                   .gsub(/\s+/, ' ')
                                   .gsub('&rsquo;', "'")
                                   .gsub('&#39;', "'")
                                   .gsub('&quot;', '"')
                                   .gsub('&amp;', '&')
                                   .gsub('&nbsp;', ' ')
                                   .strip
    post_text += plain_coaching

    # Create YAML front matter (edition_number derived from filename)
    front_matter = {
      'quote_text' => quote_text,
      'quote_author' => quote_author,
      'subject_suffix' => subject_suffix,
      'last_sent_at' => mail.date.to_s,
      'hosted_cartoon_url' => cartoon_url,
      'andertoon_number' => 'TODO'
    }

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
      f.puts ""
    end

    puts "Created: #{filename} (#{monday_date})"
    created_count += 1
    edition_number += 1

  rescue => e
    puts "Error processing #{monday_date}: #{e.message}"
    edition_number += 1
    next
  end
end

puts ""
puts "=" * 60
puts "Processing complete!"
puts "Created: #{created_count} edition files"
puts "Skipped: #{skipped_count} edition files (already exist)"
puts "Next edition number: #{edition_number}"
puts ""
puts "NOTE: Update 'andertoon_number' fields manually (currently set to 'TODO')"
puts "=" * 60
