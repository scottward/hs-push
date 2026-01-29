# HabitStack Push - Email Scheduling System

## Quick Reference

When asked to schedule emails, check the `sent/` folder to find the last scheduled edition and date, then recommend commands based on that.

## User Preferences

- **Skip the last two weeks of December** (Christmas/New Year period). The final email of the year should go out on or before December 14th, avoiding December 21-28.

## How to Schedule Emails

### Step 1: Find the last scheduled email
Check `sent/` for the most recent file. Filename format: `YYYY-MM-DD-HHMM-edition-NN-subject.html`

### Step 2: Calculate the end edition carefully
1. Determine the start date (one week after last scheduled)
2. Calculate the last acceptable send date (December 14th or closest Monday/send-day before December 21st)
3. Count the weeks: `(last_date - start_date) / 7 + 1 = number_of_editions`
4. **Verify by calculating the actual last date**: `start_date + (num_editions - 1) * 7`
5. Ensure that date is on or before December 14th (or at minimum before December 21st)

### Step 3: Build HTML emails
```bash
ruby scripts/build_emails.rb \
  --start <next-edition-number> \
  --end <calculated-end-edition> \
  --start-date <one-week-after-last-scheduled> \
  --start-time 0800
```

**Always double-check**: The build output shows all dates. Verify the last one is correct before proceeding.

### Step 3: Test (optional but recommended)
```bash
ruby scripts/schedule_emails.rb
```
Sends to test lists for verification.

### Step 4: Schedule to production
```bash
ruby scripts/schedule_emails.rb --live
```

## System Overview

- **52 editions** total (edition-01 through edition-52)
- Editions are scheduled **weekly** (7-day intervals)
- Send time: **8:00 AM PST** (16:00 UTC)
- Uses **SendGrid Marketing API** for scheduling

## Key Paths

- Edition source files: `editions/edition-NN-*.md`
- Queued emails: `queued/`
- Sent (production): `sent/`
- Sent (test): `sent-test/`
- Logs: `logs/`
- Config: `config.yaml`
