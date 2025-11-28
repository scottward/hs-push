# HabitStack Push - Email Management System

## Overview

This project manages the HabitStack Push weekly newsletter emails. The system converts structured data from multiple sources into a standardized markdown format, then generates HTML emails for scheduling on SendGrid.

## Data Sources

1. **monday_emails_2025-11-15T00_34_16.csv** - Zapier table export containing recent editions with complete metadata (including some not yet sent)
2. **all emails sent.eml** - Gmail export of all sent emails, primary source for extracting edition content and HTML template
3. **HabitStack Push Editions 2025.docx** - Word document with earlier editions (may not be needed - content available in .eml)
4. **HabitStack Push Editions 2025.pdf** - PDF version of the Word document (may not be needed - content available in .eml)

**Note:** A fresh CSV export will be needed to capture any editions added since 2025-11-15.

## System Architecture

### 1. Edition Files (`editions/`)

Each weekly email is stored as a markdown file: `editions/edition-NN-subject-suffix.md`

**Front Matter Fields:**
- `edition_number`: The edition number (also in filename)
- `quote_text`: The motivational quote
- `quote_author`: Author of the quote
- `subject_suffix`: Subject line suffix (used with emoji prefix, also in filename)
- `last_sent_at`: Timestamp of last send (tracks when it was sent)
- `hosted_cartoon_url`: URL to the Andertoons cartoon image
- `andertoon_number`: Andertoons cartoon ID number

**Body Content:**
Three markdown sections separated by headers:
- `## Email Content` - Markdown version of the coaching content (converted from coaching_html)
- `## Post Text` - Plain text version for social media posts (multi-line, non-HTML)
- `## Feedback` - Free-form text for user feedback received (if any)

### 2. HTML Template (`template.html`)

Located in the root directory. Manually retrieved from Zapier/SendGrid. Contains placeholder variables:
- `{{quote_text}}`
- `{{quote_author}}`
- `{{coaching_html}}`
- `{{hosted_cartoon_url}}`
- `{{edition_number}}` - Displayed in fine print at bottom of email

### 3. Configuration (`config.yaml`)

Configuration file in root directory containing:
- SendGrid list ID for recipient list
- Other SendGrid/API settings

### 4. Directory Structure

- `editions/` - Markdown source files for each edition
- `queued/` - HTML files ready to be sent, with scheduled date/time in filename
- `sent/` - Archive of HTML files after they've been scheduled via SendGrid
- `scripts/` - Ruby scripts for processing
- `logs/` - Log files for scheduled email operations
- `template.html` - HTML email template (root directory)

### 5. Ruby Scripts

**`scripts/csv_to_markdown.rb`** (one-time conversion)
- Reads the CSV file
- Converts each row to a markdown file with YAML front matter
- Converts HTML coaching content to markdown
- Saves to `editions/edition-NN-subject-suffix.md`

**`scripts/eml_to_markdown.rb`** (one-time extraction)
- Parses `all emails sent.eml` to extract all sent editions
- Converts each email to markdown format with front matter
- Updates/creates edition files with definitive content from sent emails
- Populates `last_sent_at` timestamps

**`scripts/queue_emails.rb`** (scheduling workflow)
- Reads markdown edition files
- Converts markdown coaching content back to HTML
- Merges data into the HTML template
- Validates all required fields are present
- Creates HTML files in `queued/` directory with format: `YYYY-MM-DD-HHMM-edition-NN-subject.html`
- Parameters:
  - `--start N` - Starting edition number
  - `--end M` - Ending edition number
  - `--start-date YYYY-MM-DD` - Date for first edition
  - `--start-time HHMM` - Time for first edition
  - Automatically schedules subsequent editions at 7-day intervals

**`scripts/schedule_queued_emails.rb`** (SendGrid integration)
- Reads HTML files from `queued/` directory
- Schedules each email via SendGrid API at the date/time specified in filename
- Only moves successfully scheduled emails to `sent/` directory (after receiving success confirmation from SendGrid)
- Updates `last_sent_at` in corresponding markdown edition file
- Logs all operations and results
- Reads SendGrid API key from environment variable
- Reads SendGrid list ID from `config.yaml`

## Workflow

### Initial Setup (One-time)
1. **Extract from .eml**: Run `eml_to_markdown.rb` to extract all sent editions from email archive (skips editions that already exist)
2. **Import from CSV**: Run `csv_to_markdown.rb` to import remaining editions (skips editions that already exist from .eml extraction)

### Regular Scheduling Workflow
1. **Edit**: Create or edit markdown files in `editions/` as needed
2. **Queue**: Run `queue_emails.rb --start N --end M --start-date YYYY-MM-DD --start-time HHMM`
   - Generates HTML files in `queued/` directory
   - Review queued HTML files to confirm content is correct
3. **Schedule**: Run `schedule_queued_emails.rb` to schedule via SendGrid API
   - Schedules all emails in `queued/` directory for future send dates
   - Moves successfully scheduled files to `sent/` archive
   - Updates `last_sent_at` timestamps in edition files
   - Creates log file with results
   - Review scheduled emails in SendGrid UI to verify scheduling
4. **Post to LinkedIn**: Use post text from edition files to create LinkedIn posts (manual or future automation)

## Future Enhancements

- LinkedIn API integration for automated post scheduling
- Test email functionality (send preview to specific address before scheduling)
