# HabitStack Push - Quick Start Guide

## What You Have Now

✅ **Complete email management system** for HabitStack Push weekly newsletters

✅ **8 edition files** imported from CSV (editions 34-41)

✅ **All scripts created and tested:**
- Import from CSV
- Generate HTML emails
- Schedule via SendGrid API
- Status checking
- Edition listing

## Before You Send Your First Email

### 1. Configure SendGrid

Edit `config.yaml` and add your SendGrid configuration:

```yaml
sendgrid:
  name_prefix: "HS Push - "
  sender_id: YOUR_SENDER_ID          # Get from SendGrid dashboard
  suppression_group_id: YOUR_GROUP_ID

  # Production lists (for --live mode)
  list_ids: ["your-production-list-id"]
  segment_ids: ["your-production-segment-id"]  # Optional

  # Test lists (for default test mode)
  test_list_ids: ["your-test-list-id"]
  test_segment_ids: []  # Optional

email:
  subject_prefix: "🕗 Plan your week // "
```

### 2. API Key (Optional Setup)

The script will prompt for your API key if not set. To avoid the prompt, set it in your environment:

```bash
export SENDGRID_API_KEY='your-sendgrid-api-key-here'
```

To make it permanent, add to your `~/.bashrc` or `~/.zshrc`:

```bash
echo 'export SENDGRID_API_KEY="your-sendgrid-api-key-here"' >> ~/.bashrc
source ~/.bashrc
```

## Your First Send (Test Run)

### Step 1: Check System Status

```bash
ruby scripts/status.rb
```

### Step 2: Build ONE Email First

```bash
# Build just edition 34 for testing
ruby scripts/build_emails.rb \
  --start 34 \
  --end 34 \
  --start-date 2025-11-25 \
  --start-time 0800
```

### Step 3: Review the HTML

```bash
# List queued files
ls -lh queued/

# Open in browser to preview
# (Replace with your preferred browser)
firefox queued/2025-11-25-0800-edition-34-*.html
# or
google-chrome queued/2025-11-25-0800-edition-34-*.html
```

Verify:
- Quote displays correctly
- Coaching content is properly formatted
- Cartoon image loads
- All links work

### Step 4: Schedule (When Ready)

**IMPORTANT:** Before running this, make sure:
1. SendGrid test lists are configured in config.yaml
2. You've reviewed the HTML and it looks perfect

```bash
# TEST MODE - Schedule to test list (default)
ruby scripts/schedule_emails.rb
```

The script will prompt for your API key if not already set in environment.

**After verifying test email in SendGrid:**
```bash
# PRODUCTION MODE - Schedule to production lists
ruby scripts/schedule_emails.rb --live
```

### Step 5: Verify in SendGrid

1. Go to https://app.sendgrid.com/marketing/singleSends
2. Find your scheduled email (named "HS Push - YYYY-MM-DD HH:MM - Edition XX")
3. Verify the email is scheduled for the correct date/time
4. Check the recipient list (should be test list first)
5. Send a test email to yourself if possible
6. After verifying test, delete test schedule and run with `--live` flag

### Step 6: Check Logs

```bash
# View the log file
ls -lt logs/
cat logs/schedule_*.log
```

## Regular Workflow (After First Test)

### Weekly Scheduling

Schedule multiple editions at once:

```bash
# Build editions 35-40, starting Nov 24
ruby scripts/build_emails.rb \
  --start 35 \
  --end 40 \
  --start-date 2025-11-24 \
  --start-time 0800

# Review built HTML files
ls queued/

# Schedule to test list first
ruby scripts/schedule_emails.rb

# After verifying in SendGrid, schedule to production
ruby scripts/schedule_emails.rb --live
```

### Adding New Editions

Two options:

**Option A: Add to CSV and Import**
1. Update your Monday/Zapier CSV export
2. Run: `ruby scripts/csv_to_markdown.rb new_export.csv`
3. Manually add andertoon numbers to new files

**Option B: Create Manually**
1. Copy an existing edition file as template
2. Update all front matter fields
3. Write new content
4. Save as `editions/edition-XX-subject-suffix.md`

### Monthly Maintenance

```bash
# Check what you have
ruby scripts/list_editions.rb

# Check system status
ruby scripts/status.rb

# Clean up old logs (optional)
ls -lt logs/
# Delete old logs if needed
```

## Common Commands Reference

```bash
# System status
ruby scripts/status.rb

# List all editions
ruby scripts/list_editions.rb

# Get help
ruby scripts/help.rb

# Import from CSV
ruby scripts/csv_to_markdown.rb [filename.csv]

# Build emails
ruby scripts/build_emails.rb \
  --start N --end M \
  --start-date YYYY-MM-DD \
  --start-time HHMM

# Schedule emails (test mode)
ruby scripts/schedule_emails.rb

# Schedule emails (production mode)
ruby scripts/schedule_emails.rb --live
```

## Troubleshooting

### "Edition file not found"
Run: `ruby scripts/csv_to_markdown.rb`

### "No test lists or segments configured"
Edit `config.yaml` and set your test_list_ids

### "No production lists or segments configured"
Edit `config.yaml` and set your list_ids and segment_ids

### Script prompts for API key
Either enter it when prompted, or set: `export SENDGRID_API_KEY='your-key'`

### Scheduling failed
- Check logs in `logs/` directory
- Files remain in `queued/` until successfully scheduled
- Fix issue and re-run schedule script

## Need Help?

1. Read the full `README.md` for detailed documentation
2. Run `ruby scripts/help.rb` for quick reference
3. Contact: sw@habitstack.com

## Next Steps

1. ✅ Test with one email first
2. ✅ Verify in SendGrid dashboard
3. ✅ Schedule your next batch
4. Consider: Export fresh CSV to get latest editions
5. Consider: Add automation for LinkedIn posts

---

**Ready to send your first email?** Start with Step 1 above!
