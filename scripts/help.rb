#!/usr/bin/env ruby

puts <<~HELP
  HabitStack Push - Email Management System
  ==========================================

  COMMON TASKS:

  1. Import edition data from CSV:
     ruby scripts/csv_to_markdown.rb

  2. Build HTML emails from editions:
     ruby scripts/build_emails.rb \\
       --start 35 \\
       --end 40 \\
       --start-date 2025-11-24 \\
       --start-time 0800

  3. Review built emails:
     ls -lh queued/
     # Open HTML files in browser to preview

  4. Schedule emails via SendGrid:
     ruby scripts/schedule_emails.rb          # Test mode (default)
     ruby scripts/schedule_emails.rb --live   # Live mode (production)

  5. Check logs:
     ls -lt logs/
     # View most recent log file

  6. List edition files:
     ls -1 editions/ | sort

  7. Extract historical emails from .eml:
     ruby scripts/eml_to_markdown.rb --start-edition 27

  BEFORE FIRST USE:

  1. Install dependencies:
     bundle install

  2. Configure SendGrid:
     # Edit config.yaml with list_ids, test_list_ids, sender_id, etc.
     # Script will prompt for SENDGRID_API_KEY if not set

  DIRECTORY STRUCTURE:

  editions/   - Markdown source files for each email edition
  queued/     - HTML files ready to be sent (review before scheduling)
  sent/       - Archive of HTML files (production mode)
  sent-test/  - Archive of HTML files (test mode)
  scripts/    - Ruby scripts for processing
  logs/       - Log files from scheduling operations

  NEED HELP?

  - Read README.md for detailed documentation
  - Contact: sw@habitstack.com

HELP
