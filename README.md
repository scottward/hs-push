# HabitStack Push - Email Management System

This project manages the HabitStack Push weekly newsletter emails. The system converts structured data from multiple sources into a standardized markdown format, then generates HTML emails for scheduling on SendGrid.

## Quick Start

1. **Install Dependencies**
   ```bash
   bundle install
   ```

2. **Import Edition Data**
   ```bash
   # Import from CSV (creates editions that don't exist)
   ruby scripts/csv_to_markdown.rb

   # Or import from .eml file (if needed)
   ruby scripts/eml_to_markdown.rb --start-edition 27
   ```

3. **Build HTML Emails**
   ```bash
   ruby scripts/build_emails.rb \
     --start 35 \
     --end 40 \
     --start-date 2025-11-24 \
     --start-time 0800
   ```

4. **Review Built Emails**
   - Open HTML files in `queued/` directory to verify content
   - Make any necessary edits before scheduling

5. **Schedule via SendGrid**
   ```bash
   # TEST MODE (default - uses test lists)
   ruby scripts/schedule_emails.rb

   # PRODUCTION MODE (uses production lists)
   ruby scripts/schedule_emails.rb --live
   ```

   **Note:** The script will prompt for your SendGrid API key if not set in environment.

## System Architecture

### Directory Structure

```
hs-push/
├── editions/              # Markdown source files for each edition
├── queued/                # HTML files ready to be sent
├── sent/                  # Archive of sent HTML files (production)
├── sent-test/             # Archive of sent HTML files (test mode)
├── scripts/               # Ruby scripts for processing
├── logs/                  # Log files for operations
├── template.html          # HTML email template
├── config.yaml            # SendGrid configuration
└── Gemfile                # Ruby dependencies
```

### Edition Files

Each weekly email is stored as a markdown file: `editions/edition-NN-subject-suffix.md`

**Front Matter Fields:**
- `edition_number` - The edition number (also in filename)
- `quote_text` - The motivational quote
- `quote_author` - Author of the quote
- `subject_suffix` - Subject line suffix (used with emoji prefix)
- `last_sent_at` - Timestamp of last send (updated after scheduling)
- `hosted_cartoon_url` - URL to the Andertoons cartoon image
- `andertoon_number` - Andertoons cartoon ID number

**Content Sections:**
- `## Email Content` - Markdown version of the coaching content
- `## Post Text` - Plain text version for social media posts
- `## Feedback` - User feedback received (if any)

**Example Edition File:**
```markdown
---
edition_number: 35
quote_text: Lack of direction, not lack of time, is the problem.
quote_author: Zig Ziglar
subject_suffix: "The real problem 🤔"
hosted_cartoon_url: http://cdn.mcauto-images-production.sendgrid.net/...
andertoon_number: 1011
last_sent_at: '2025-10-06T08:00:00+00:00'
---

## Email Content

Actually, "lack of direction" is NOT usually the problem.

The more common problem is **overabundance** of possible directions...

## Post Text

"Lack of direction, not lack of time, is the problem."
— Zig Ziglar

Actually, "lack of direction" is NOT usually the problem...

## Feedback

Oleksa 2025-10: This was great Scott and helpful.
```

## Scripts

### 1. `csv_to_markdown.rb` - Import from CSV

Imports edition data from Monday/Zapier CSV export and creates markdown files for editions that don't already exist.

**Usage:**
```bash
ruby scripts/csv_to_markdown.rb [csv_filename]
```

**Default:** Uses `monday_emails_2025-11-15T00_34_16.csv` if no filename provided

**Features:**
- Skips editions that already exist (preserves manually edited content)
- Converts HTML coaching content to markdown
- Generates post text for social media
- Includes feedback if present in CSV

### 2. `eml_to_markdown.rb` - Extract from Email Archive

Extracts sent emails from Gmail .eml export and converts them to markdown edition files. Useful for archiving historical emails.

**Usage:**
```bash
ruby scripts/eml_to_markdown.rb [--start-edition N]
```

**Default starting edition:** 27 (February 17, 2025 email)

**Features:**
- Parses embedded email messages from .eml file
- Extracts quote, coaching content, and cartoon from HTML
- Records sent timestamp in `last_sent_at` field
- Skips editions that already exist
- Sets `andertoon_number` to 'TODO' for manual entry

**Note:** After running, manually update the `andertoon_number` field in each file

### 3. `build_emails.rb` - Generate HTML Files

Reads markdown edition files, converts them to HTML using the template, and builds them with scheduled dates/times.

**Usage:**
```bash
ruby scripts/build_emails.rb \
  --start N \
  --end M \
  --start-date YYYY-MM-DD \
  --start-time HHMM
```

**Required Arguments:**
- `--start N` - Starting edition number
- `--end M` - Ending edition number
- `--start-date YYYY-MM-DD` - Date for first edition
- `--start-time HHMM` - Time for first edition (e.g., 0800 for 8:00 AM)

**Scheduling:**
- First edition scheduled for specified date/time
- Subsequent editions scheduled at 7-day intervals

**Example:**
```bash
# Build editions 35-40, starting Nov 24 at 8:00 AM
ruby scripts/build_emails.rb \
  --start 35 \
  --end 40 \
  --start-date 2025-11-24 \
  --start-time 0800
```

**Output:**
- Creates HTML files in `queued/` directory
- Filename format: `YYYY-MM-DD-HHMM-edition-NN-subject.html`
- Example: `2025-11-24-0800-edition-35-the-real-problem.html`

**Validation:**
- Checks for all required front matter fields
- Converts markdown coaching content to HTML
- Substitutes all template variables

### 4. `schedule_emails.rb` - Schedule via SendGrid

Reads HTML files from `queued/` directory and schedules them via SendGrid API at the date/time specified in the filename.

**Modes:**
- **TEST MODE** (default): Uses test lists/segments from config.yaml, archives to `sent-test/`
- **LIVE MODE** (`--live` flag): Uses production lists/segments, archives to `sent/`

**Prerequisites:**
Update `config.yaml` with your SendGrid configuration:
```yaml
sendgrid:
  name_prefix: "HS Push - "
  sender_id: 5511240
  suppression_group_id: 24757

  # Production lists
  list_ids: ["93ac53e8-62d6-460b-a852-3e044c7a4d13"]
  segment_ids: ["0e6d036a-1881-46d4-a3b6-71a8d45131dd"]

  # Test lists
  test_list_ids: ["fcbf06aa-6b8f-495a-8b78-6cf2d4e776c4"]
  test_segment_ids: []

email:
  subject_prefix: "🕗 Plan your week // "
```

**Usage:**
```bash
# TEST MODE (default - uses test lists)
ruby scripts/schedule_emails.rb

# PRODUCTION MODE (uses production lists)
ruby scripts/schedule_emails.rb --live
```

**API Key:**
The script will:
1. Check for `SENDGRID_API_KEY` environment variable
2. If not found, prompt you to enter it interactively
3. Set it for the current session

To set it permanently:
```bash
export SENDGRID_API_KEY='your-api-key-here'
echo 'export SENDGRID_API_KEY="your-key"' >> ~/.bashrc
```

**Process:**
1. Reads all HTML files from `queued/` directory
2. Parses scheduled date/time from filename
3. Reads corresponding edition file for subject line
4. Creates Single Send via SendGrid API (POST /v3/marketing/singlesends)
5. Schedules the Single Send (PUT /v3/marketing/singlesends/{id}/schedule)
6. **Only after success confirmation:**
   - Moves file from `queued/` to `sent/` (or `sent-test/` in test mode)
   - Updates `last_sent_at` in edition markdown file
7. Logs all operations to `logs/` directory

**Important Notes:**
- Emails remain in `queued/` directory until successfully scheduled
- If scheduling fails, files stay in `queued/` for retry
- Check SendGrid dashboard to verify scheduled emails: https://app.sendgrid.com/marketing/singleSends
- Log file created with timestamp: `logs/schedule_YYYY-MM-DD_HH-MM-SS.log`
- **Always test with test mode first** before using `--live` flag

**SendGrid API:**
Uses the SendGrid Marketing Single Sends API with a two-step process:
1. Create the single send with content and recipient configuration
2. Schedule it for the specified send time

## HTML Template

The `template.html` file contains the email structure with placeholder variables:

- `{{quote_text}}` - The motivational quote
- `{{quote_author}}` - Quote attribution
- `{{coaching_html}}` - HTML coaching content (converted from markdown)
- `{{hosted_cartoon_url}}` - Cartoon image URL
- `{{edition_number}}` - Edition number (shown in fine print)

The template is manually maintained. If you update the design in Zapier/SendGrid, copy the new template and replace the dynamic values with the placeholder variables.

## Configuration

### `config.yaml`

```yaml
sendgrid:
  name_prefix: "HS Push - "
  sender_id: 5511240
  suppression_group_id: 24757

  # Production lists/segments
  list_ids: ["YOUR_PRODUCTION_LIST_ID"]
  segment_ids: ["YOUR_PRODUCTION_SEGMENT_ID"]

  # Test lists/segments
  test_list_ids: ["YOUR_TEST_LIST_ID"]
  test_segment_ids: []

  from_email: "sw@habitstack.com"
  from_name: "Scott Ward"
  reply_to_email: "sw@habitstack.com"

email:
  subject_prefix: "🕗 Plan your week // "
```

**Key Fields:**
- `list_ids` / `test_list_ids`: SendGrid Marketing list IDs (arrays)
- `segment_ids` / `test_segment_ids`: SendGrid segment IDs (arrays, optional)
- `sender_id`: SendGrid verified sender ID
- `suppression_group_id`: Unsubscribe group ID
- `name_prefix`: Prefix for Single Send names in SendGrid dashboard

### Environment Variables

- `SENDGRID_API_KEY` - Your SendGrid API key (optional - will prompt if not set)

## Workflow

### Initial Setup (One-time)

1. **Install dependencies:**
   ```bash
   bundle install
   ```

2. **Import historical data:**
   ```bash
   # Option A: From CSV export
   ruby scripts/csv_to_markdown.rb

   # Option B: From .eml archive (if needed)
   ruby scripts/eml_to_markdown.rb --start-edition 27
   ```

3. **Configure SendGrid:**
   - Update `config.yaml` with your SendGrid list IDs (both test and production)
   - Get sender_id and suppression_group_id from SendGrid dashboard
   - Optionally set `SENDGRID_API_KEY` environment variable (or enter when prompted)
   - Test with a single edition before bulk scheduling

### Regular Scheduling Workflow

1. **Create/Edit Editions**
   - Create new markdown files in `editions/` directory
   - Or edit existing files to update content

2. **Build HTML Emails**
   ```bash
   ruby scripts/build_emails.rb \
     --start 41 \
     --end 45 \
     --start-date 2025-12-01 \
     --start-time 0800
   ```

3. **Review**
   - Open HTML files in `queued/` directory
   - Verify content, formatting, and images
   - Make any necessary edits to edition files
   - Re-run build script if changes made

4. **Schedule (Test First!)**
   ```bash
   # TEST MODE - Schedule to test list first
   ruby scripts/schedule_emails.rb

   # Verify in SendGrid dashboard, then schedule to production
   ruby scripts/schedule_emails.rb --live
   ```

5. **Verify**
   - Check log file in `logs/` directory
   - Verify scheduled emails in SendGrid dashboard: https://app.sendgrid.com/marketing/singleSends
   - Confirm files moved to `sent/` (or `sent-test/`) directory
   - Check `last_sent_at` updated in edition files

6. **LinkedIn Posting** (Manual for now)
   - Use the `## Post Text` section from edition files
   - Schedule LinkedIn posts manually
   - Future: Automate via LinkedIn API

## Data Sources

The system can import from multiple sources:

1. **CSV Export** (Primary Source)
   - Export from Monday/Zapier
   - Contains complete edition metadata
   - Includes editions not yet sent

2. **Gmail .eml Export** (Historical Archive)
   - All previously sent emails
   - Used to extract actual sent content and timestamps
   - Preserves the definitive version that subscribers received

3. **Word/PDF Documents** (Backup)
   - Earlier editions before current system
   - May not be needed if content available in .eml

## Troubleshooting

### Edition files not found
- Ensure edition files exist in `editions/` directory
- Check filename format: `edition-NN-subject-suffix.md` (with leading zero for numbers < 10)
- Run import script: `ruby scripts/csv_to_markdown.rb`

### Missing required fields
- Validate YAML front matter in edition files
- Required fields: `edition_number`, `quote_text`, `quote_author`, `subject_suffix`, `hosted_cartoon_url`
- Check for proper YAML formatting (quotes around strings with special characters)

### SendGrid API errors
- Verify `SENDGRID_API_KEY` is correct (enter when prompted or set in environment)
- Check API key has correct permissions (Marketing Campaigns)
- Verify list_ids and segment_ids are correct in `config.yaml`
- Check sender_id and suppression_group_id are valid
- Review error messages in log file
- Confirm you're using correct mode (test vs live)

### HTML rendering issues
- Verify `template.html` contains all placeholder variables
- Check that markdown content converts properly (test in browser)
- Ensure image URLs are accessible
- Review generated HTML in `queued/` directory before scheduling

### Scheduling failed
- Emails remain in `queued/` until successfully scheduled
- Check log file for detailed error messages
- Fix issues and re-run `schedule_emails.rb`
- Files won't move to `sent/` (or `sent-test/`) until SendGrid confirms success
- Verify you're in correct mode (test vs live)

## Future Enhancements

- [ ] LinkedIn API integration for automated post scheduling
- [ ] Test email functionality (send preview to specific address)
- [ ] Web preview interface for edition files
- [ ] Automated fresh CSV export from Monday/Zapier
- [ ] Batch operations for edition management
- [ ] Email analytics integration

## Development

### Adding New Fields

To add a new field to edition files:

1. Update YAML front matter in edition files
2. Modify CSV import script (`csv_to_markdown.rb`)
3. Update HTML template if needed (`template.html`)
4. Update build script to handle new field (`build_emails.rb`)
5. Update this README documentation

### Testing

Test with a small batch before scheduling to full list:

```bash
# Build just 1-2 editions
ruby scripts/build_emails.rb \
  --start 35 \
  --end 35 \
  --start-date 2025-12-01 \
  --start-time 0800

# Review HTML manually
open queued/2025-12-01-0800-edition-35-*.html

# Test scheduling (uses test list by default)
ruby scripts/schedule_emails.rb

# Verify in SendGrid, then schedule to production
ruby scripts/schedule_emails.rb --live
```

## License

Proprietary - HabitStack

## Support

For issues or questions, contact sw@habitstack.com
