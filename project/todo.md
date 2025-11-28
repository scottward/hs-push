# HabitStack Push - Implementation Todo List

## NEXT UP

* **Configure SendGrid** - Add your list ID to config.yaml and set SENDGRID_API_KEY
* **Test with one edition** - Queue and schedule a single test email to verify everything works
* Export fresh CSV from Monday/Zapier to capture recent additions (optional - for newer editions)

## Phase 1: Initial Setup ✅ COMPLETE

- [x] Create `overview.md` with system architecture
- [x] Create `todo.md` with implementation steps
- [x] Create directory structure:
  - [x] `editions/` - Markdown source files
  - [x] `queued/` - HTML files ready to send
  - [x] `sent/` - Archive of sent HTML files
  - [x] `scripts/` - Ruby scripts
  - [x] `logs/` - Log files for operations

## Phase 2: Get HTML Template ✅ COMPLETE

- [x] ~~Manually go to Zapier and retrieve SendGrid template~~ Extracted from .eml file
- [x] Save as `template.html` in root directory
- [x] Manually add `{{edition_number}}` placeholder to fine print at bottom of template
- [x] Verify template contains all required placeholders:
  - [x] `{{quote_text}}`
  - [x] `{{quote_author}}`
  - [x] `{{coaching_html}}`
  - [x] `{{hosted_cartoon_url}}`
  - [x] `{{edition_number}}`

## Phase 3: EML to Markdown Extraction (Primary Content Source) ✅ COMPLETE

- [x] ~~USER: Provide starting edition number for February 17, 2025 email ("Habits Not Magic")~~ Default to 27
- [x] Create `scripts/eml_to_markdown.rb`
- [x] Parse `all emails sent.eml` file structure
- [x] Extract all sent emails starting from February 17, 2025 (subject suffix: "Habits Not Magic")
- [x] For each email, extract:
  - [x] Edition number (start from user-provided number, increment for each subsequent email)
  - [x] Quote text and author
  - [x] Subject suffix
  - [x] Sent timestamp (for `last_sent_at`)
  - [x] Coaching content HTML
  - [x] Cartoon URL
  - [x] Andertoons number (placeholder: "TODO")
- [x] Convert HTML coaching content to markdown
  - [x] Use `reverse_markdown` gem
  - [x] Handle `<p>`, `<strong>`, `<em>`, `<ul>`, `<li>` tags
- [x] Generate post text (strip HTML, format for social media)
- [x] Create markdown files with format: `editions/edition-NN-subject-suffix.md`
- [x] Structure each file:
  - [x] YAML front matter with all metadata (andertoon_number as "TODO")
  - [x] `## Email Content` section with markdown
  - [x] `## Post Text` section with plain text
  - [x] `## Feedback` section (empty initially)
- [x] Test script and verify output
- [ ] USER: Manually populate andertoon_number for each extracted edition (replace "TODO" values) - *Not needed for CSV imports*

## Phase 4: CSV to Markdown Conversion (Supplementary Data) ✅ COMPLETE

- [x] ~~USER: Export fresh CSV from Monday/Zapier~~ Using existing CSV
- [x] Create `scripts/csv_to_markdown.rb`
- [x] Add CSV parsing (read latest CSV export)
- [x] Add YAML front matter generation with fields:
  - [x] `edition_number`
  - [x] `quote_text`
  - [x] `quote_author`
  - [x] `subject_suffix`
  - [x] `last_sent_at` (convert from `send_at`, may be null for unsent)
  - [x] `hosted_cartoon_url`
  - [x] `andertoon_number`
- [x] Add HTML to Markdown conversion for `coaching_html` field (using reverse_markdown gem)
- [x] Generate post text from coaching content
- [x] Create three markdown sections: `## Email Content`, `## Post Text`, and `## Feedback`
- [x] Generate filename: `editions/edition-NN-subject-suffix.md`
- [x] Add logic to skip editions that already exist (from .eml extraction)
- [x] Test script on CSV file
- [x] Verify all editions are created correctly

## Phase 5: Validate Edition Files ✅ COMPLETE

- [x] Review all edition files in `editions/` directory
- [x] Ensure all editions present (8 editions: 34-41)
- [x] Validate all required front matter fields are present
- [x] Spot-check markdown formatting and post text quality

## Phase 6: Queue Emails Script ✅ COMPLETE

- [x] Create `scripts/queue_emails.rb`
- [x] Add command-line argument parsing:
  - [x] `--start N` (required) - Starting edition number
  - [x] `--end M` (required) - Ending edition number
  - [x] `--start-date YYYY-MM-DD` (required) - Date for first edition
  - [x] `--start-time HHMM` (required) - Time for first edition
- [x] Add YAML front matter parsing from markdown files
- [x] Add markdown to HTML conversion for coaching content (using kramdown gem)
- [x] Add template loading from `template.html` in root directory
- [x] Add variable substitution:
  - [x] Replace `{{quote_text}}` with front matter value
  - [x] Replace `{{quote_author}}` with front matter value
  - [x] Replace `{{coaching_html}}` with converted markdown from `## Email Content` section
  - [x] Replace `{{hosted_cartoon_url}}` with front matter value
  - [x] Replace `{{edition_number}}` with edition number
- [x] Add field validation (ensure all required fields present)
- [x] Calculate scheduling dates (7-day intervals from start date)
- [x] Generate output filename: `queued/YYYY-MM-DD-HHMM-edition-NN-subject.html`
- [x] Output HTML files to `queued/` directory
- [x] Display summary of queued emails with scheduled dates/times
- [x] Test with a small range of editions
- [x] Verify HTML renders correctly in browser

## Phase 7: SendGrid Integration ✅ COMPLETE

- [x] Create `config.yaml` in root directory with SendGrid list ID (placeholder)
- [x] Create `scripts/schedule_queued_emails.rb`
- [x] Add SendGrid API key configuration (read from environment variable)
- [x] Read SendGrid list ID from `config.yaml`
- [x] Read all HTML files from `queued/` directory
- [x] Parse filename to extract scheduled date/time and edition info
- [x] For each queued email:
  - [x] Extract edition number from filename
  - [x] Read corresponding markdown file for subject line
  - [x] Build subject: emoji + subject_suffix
  - [x] Schedule email via SendGrid API with:
    - [x] Subject line
    - [x] HTML body from file
    - [x] Scheduled send time from filename
    - [x] Recipient list (from config.yaml)
- [x] Wait for success confirmation from SendGrid API
- [x] Only after success: move file from `queued/` to `sent/`
- [x] Update `last_sent_at` in edition markdown file
- [x] Log all operations and results to `logs/` directory

## Phase 8: Testing & Validation ⚠️ NEEDS USER ACTION

- [x] Test end-to-end workflow with a few test editions (tested queue script)
- [x] Verify queued HTML matches expected format
- [ ] **USER ACTION: Test SendGrid scheduling with future dates** - Need to configure SendGrid first
- [ ] **USER ACTION: Verify sent files move to archive correctly after successful scheduling**
- [ ] **USER ACTION: Verify `last_sent_at` updates correctly**
- [ ] **USER ACTION: Compare generated HTML with original sent emails for quality**
- [ ] **USER ACTION: Check scheduled emails in SendGrid UI**
- [ ] Fix any formatting issues (if found)

## Phase 9: Documentation ✅ COMPLETE

- [x] Create main README.md with:
  - [x] System overview
  - [x] Installation instructions
  - [x] Required Ruby gems (Gemfile)
  - [x] Environment variables (SendGrid API key)
  - [x] Usage examples for each script
  - [x] Workflow documentation
- [x] Add inline code documentation/comments
- [x] Document file formats and conventions
- [x] Created QUICKSTART.md for step-by-step setup
- [x] Created IMPLEMENTATION_SUMMARY.md

## Phase 10: Future Enhancements 🔮 OPTIONAL

- [ ] LinkedIn API integration for automated post scheduling
  - [ ] Extract post text from `## Post Text` section
  - [ ] Schedule LinkedIn posts for same time as email
- [ ] Test email functionality
  - [ ] Add `--test-email` flag to queue_emails.rb
  - [ ] Send preview to specific address before scheduling

## Additional Scripts Created ✅ BONUS

- [x] `scripts/status.rb` - System health check
- [x] `scripts/list_editions.rb` - Edition inventory
- [x] `scripts/help.rb` - Quick reference

## Notes

- Using Ruby for all scripting ✅
- File-based system, no database ✅
- Using reverse_markdown gem for HTML to Markdown conversion ✅
- Using kramdown gem for Markdown to HTML conversion ✅
- Dependencies properly resolved (nokogiri with system libraries) ✅
- 8 editions imported from CSV (34-41) ✅
