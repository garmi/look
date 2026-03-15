# LOOK Beta Launch Playbook

## Hosting

- App distribution: TestFlight
- App data and auth: Supabase
- Document storage: Supabase Storage private buckets
- AI document extraction: Supabase Edge Functions calling Claude
- Product analytics: PostHog
- Crash reporting: Sentry

## Minimum Production Setup

1. Create a Supabase project for beta only.
2. Enable email or magic-link auth if you want identifiable testers.
3. Create private storage buckets for blood reports and prescriptions.
4. Move Claude API calls behind an Edge Function before opening beta to external testers.
5. Set up PostHog events for:
   - app_opened
   - onboarding_completed
   - morning_checkin_submitted
   - medication_confirmed
   - trial_saved
   - document_uploaded
   - document_extracted
   - ask_question_submitted
6. Set up Sentry for crash and error tracking.

## What To Measure

- Activation:
  - first check-in completed
  - first medication confirmation
  - first document upload
- Retention:
  - day 1, day 7, day 14 return
  - weekly medication confirmation rate
- Safety:
  - red trial frequency
  - unresolved red logs
  - document extraction failures
- Trust:
  - feedback submissions
  - repeat uploads
  - repeat asks

## Weekly Review Loop

1. Monday: review crashes, failed uploads, red logs, and funnel drop-offs.
2. Tuesday: choose one improvement only.
3. Wednesday: ship to internal testers.
4. Thursday: compare behavior and feedback.
5. Friday: promote to external testers or roll back.

## Launch Checklist

- Supabase configured on iPhone and Mac
- Storage buckets private
- Camera/photo permissions verified on device
- Notifications verified on device
- TestFlight internal build installed
- At least 10 seeded articles and 10 real doctors in directory
- Safety copy reviewed on all major screens
- One recovery path for failed document extraction
- One feedback channel for testers

## Recommended Cohorts

- Cohort 1: personal daily use
- Cohort 2: 5 to 10 trusted testers
- Cohort 3: 25 to 50 real target users

## First Metrics Dashboard

- daily active users
- weekly active users
- questions per active user
- medication confirmations per user per week
- document upload success rate
- extraction success rate
- 7-day retention

## Immediate Next Engineering Steps

1. Move document extraction off-device into a backend function.
2. Add explicit analytics events around uploads and medication confirmation.
3. Add an in-app feedback form tied to Supabase.
4. Add reviewer/admin tools for flagged uploads and red logs.
