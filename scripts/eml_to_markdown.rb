#!/usr/bin/env ruby

require 'mail'
require 'reverse_markdown'
require 'date'
require 'yaml'

# This script extracts sent emails from the .eml file and converts them to markdown edition files
# Usage: ruby scripts/eml_to_markdown.rb [--start-edition N]
# Default starting edition is 27 (February 17, 2025 email "Habits Not Magic")

# Parse command line arguments
start_edition = 27  # Default starting edition - USER: Update this if needed
ARGV.each_with_index do |arg, i|
  if arg == '--start-edition' && ARGV[i + 1]
    start_edition = ARGV[i + 1].to_i
  end
end

puts "Starting edition number: #{start_edition}"
puts "Reading .eml file..."

# Read the entire .eml file
eml_content = File.read('all emails sent.eml')

# The .eml file contains multiple embedded email messages
# Each message starts with "Delivered-To:" after the boundary marker
# We'll split by message boundaries and process each email

# Split the file into individual messages
messages = []
current_message = ""
in_message = false

eml_content.each_line do |line|
  # Detect start of an embedded message
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

# Don't forget the last message
messages << current_message if !current_message.empty?

puts "Found #{messages.length} embedded email messages"

# Process each message
edition_number = start_edition
processed_count = 0

messages.reverse.each do |message_text|
  begin
    # Parse the email using the Mail gem
    mail = Mail.read_from_string(message_text)

    # Skip if this doesn't look like a HabitStack Push email
    next unless mail.subject && mail.subject.include?('Plan your week') ||
                (mail.subject && mail.subject =~ /🗓|📗|🌱|💚|🚩|🔥|⚡|🎯|✨/)

    # Extract subject suffix (remove emoji prefix)
    subject = mail.subject.to_s
    subject_suffix = subject.gsub(/^[[:emoji:][:space:]]+\/\/[[:space:]]*/, '').strip
    # Remove trailing emoji if present
    subject_suffix = subject_suffix.gsub(/[[:space:]]*[[:emoji:]]+[[:space:]]*$/, '').strip

    # Get the HTML part
    html_part = nil
    if mail.multipart?
      html_part = mail.html_part&.decoded
    else
      html_part = mail.decoded if mail.content_type =~ /html/
    end

    next unless html_part

    # Extract quote text and author from HTML
    quote_text = nil
    quote_author = nil

    if html_part =~ /<h2[^>]*>The Quote<\/h2>.*?<span[^>]*>(.*?)<\/span>.*?<em>(.*?)<\/em>/m
      quote_text = $1.strip.gsub(/\s+/, ' ')
      quote_author = $2.strip.gsub(/^—\s*/, '').gsub(/\s+/, ' ')
    end

    # Extract coaching HTML
    coaching_html = nil
    if html_part =~ /<h2[^>]*>The Coaching<\/h2>(.*?)<h2[^>]*>The Smile<\/h2>/m
      coaching_html = $1.strip
    end

    # Extract cartoon URL
    cartoon_url = nil
    if html_part =~ /<img[^>]*src="([^"]*mcauto-images[^"]*)"/
      cartoon_url = $1
    end

    # Get sent timestamp
    sent_at = mail.date

    # Skip if we don't have the essential data
    next unless quote_text && coaching_html && cartoon_url

    # Generate filename-safe subject suffix
    filename_suffix = subject_suffix.downcase.gsub(/[^a-z0-9\s-]/, '').gsub(/\s+/, '-')
    filename = "editions/edition-#{edition_number.to_s.rjust(2, '0')}-#{filename_suffix}.md"

    # Skip if file already exists
    if File.exist?(filename)
      puts "Skipping edition #{edition_number} - file already exists: #{filename}"
      edition_number += 1
      next
    end

    # Convert coaching HTML to markdown
    coaching_markdown = ReverseMarkdown.convert(coaching_html, unknown_tags: :bypass)

    # Generate post text (strip HTML, clean up formatting)
    post_text = "\"#{quote_text}\"\n— #{quote_author}\n\n"
    plain_coaching = coaching_html.gsub(/<[^>]+>/, ' ')
                                   .gsub(/\s+/, ' ')
                                   .gsub('&rsquo;', "'")
                                   .gsub('&#39;', "'")
                                   .gsub('&quot;', '"')
                                   .gsub('&amp;', '&')
                                   .strip
    post_text += plain_coaching

    # Create YAML front matter
    front_matter = {
      'edition_number' => edition_number,
      'quote_text' => quote_text.gsub('&rsquo;', "'").gsub('&#39;', "'").gsub('&quot;', '"'),
      'quote_author' => quote_author,
      'subject_suffix' => subject_suffix,
      'last_sent_at' => sent_at.to_s,
      'hosted_cartoon_url' => cartoon_url,
      'andertoon_number' => 'TODO'  # User will need to fill this in manually
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

    puts "Created: #{filename}"
    processed_count += 1
    edition_number += 1

  rescue => e
    puts "Error processing message: #{e.message}"
    next
  end
end

puts "\nProcessing complete!"
puts "Created #{processed_count} edition files"
puts "Next edition number: #{edition_number}"
puts "\nNOTE: You need to manually update the 'andertoon_number' field in each file (currently set to 'TODO')"
