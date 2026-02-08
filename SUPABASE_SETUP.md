# Supabase Auth & Sync Setup Guide

## Prerequisites Completed

- ✅ Database schema created (`tasks` and `voice_parse_logs` tables)
- ✅ RLS policies enabled
- ✅ SupabaseConfig.swift with URL and anon key configured
- ✅ Additional migrations created:
  - `002_add_pin_sort_profile.sql` (pin + sort + user_profiles)
  - `003_grocery_templates.sql` (grocery_stores + checklist_items)
  - `004_add_has_time.sql` (has_time flag)
  - `005_sharing.sql` (contacts + task_shares + invitations)
  - `006_contacts_phone.sql` (contacts phone number)
  - `007_profile_enhancements.sql` (phone, country_code, avatar_emoji + avatars bucket)
  - `008_migrate_country_code_to_iso.sql` (country code migration)
  - `009_ingredients_library.sql` (ingredients library)
  - `010_sharing_v2.sql` (auto-accept shares, push notifications, device_tokens)

## Manual Configuration Steps

### 1. Add Supabase Swift SDK

In Xcode:
1. File → Add Package Dependencies
2. Enter: `https://github.com/supabase/supabase-swift`
3. Select version **2.x** (latest stable)
4. Add to target: **Docket**

### 2. Configure URL Scheme for OAuth Callbacks

In Xcode:
1. Select the **Docket** target
2. Go to **Info** tab
3. Under **URL Types**, click **+**
4. Add:
   - **Identifier**: `com.jensen.docket`
   - **URL Schemes**: `com.jensen.docket`

This enables deep links for Google Sign-In and Email magic link callbacks.

### 3. Enable Sign In with Apple Capability

In Xcode:
1. Select the **Docket** target
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **Sign In with Apple**

### 4. Configure Supabase Auth Providers

#### Apple Sign-In
1. Go to [Apple Developer Portal](https://developer.apple.com/account/resources/identifiers/list)
2. Create a **Services ID** (if you don't have one)
3. Enable **Sign In with Apple**
4. Configure redirect URLs: `https://fcnweiksuonbkkhvgbih.supabase.co/auth/v1/callback`
5. In Supabase Dashboard → Auth → Providers → Apple:
   - Enable Apple provider
   - Add your Services ID and Team ID
   - Add your Key ID and Private Key

#### Google Sign-In
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create OAuth 2.0 credentials
3. Add authorized redirect URI: `https://fcnweiksuonbkkhvgbih.supabase.co/auth/v1/callback`
4. In Supabase Dashboard → Auth → Providers → Google:
   - Enable Google provider
   - Add your Client ID and Client Secret

#### Email Magic Link
1. In Supabase Dashboard → Auth → Providers → Email:
   - Enable Email provider
   - Enable **Magic Link** (disable password-based auth for security)
   - Configure email templates (optional)

### 5. Apply Database Migrations

Run these in order in Supabase SQL Editor:

1. `supabase/migrations/001_create_tasks_table.sql`
2. `supabase/migrations/002_add_pin_sort_profile.sql`
3. `supabase/migrations/003_grocery_templates.sql`
4. `supabase/migrations/004_add_has_time.sql`
5. `supabase/migrations/005_sharing.sql`
6. `supabase/migrations/006_contacts_phone.sql`
7. `supabase/migrations/007_profile_enhancements.sql`
8. `supabase/migrations/008_migrate_country_code_to_iso.sql`
9. `supabase/migrations/009_ingredients_library.sql`
10. `supabase/migrations/010_sharing_v2.sql`

### 6. Sharing + Push Notifications

**APNs Secrets (Supabase > Edge Functions > Secrets):**
- `APNS_KEY_ID`
- `APNS_TEAM_ID`
- `APNS_PRIVATE_KEY` (full .p8 contents)
- `APNS_BUNDLE_ID` (`com.jensen.docket`)
- `APNS_PRODUCTION` (`false` for dev)

**Deploy Edge Function:**
```bash
supabase functions deploy push-share-notification
```

**Create DB Webhook:**
- Table: `task_shares`
- Event: INSERT
- Target: Edge Function `push-share-notification`
- Add auth header with service role key

**Xcode Capability:**
- Add **Push Notifications** in Signing & Capabilities

### 7. Test the Setup

1. Build and run the app
2. You should see the **AuthView** on first launch
3. Try each sign-in method:
   - Apple Sign-In (should work immediately if configured)
   - Google Sign-In (will open browser, then return to app)
   - Email magic link (check your email for the link)

## Troubleshooting

### "Not authenticated" errors
- Check that Supabase URL and anon key are correct in `SupabaseConfig.swift`
- Verify auth providers are enabled in Supabase Dashboard

### Deep links not working
- Verify URL scheme is configured in Xcode (step 2 above)
- Check that redirect URLs match in provider configs

### Apple Sign-In fails
- Verify "Sign In with Apple" capability is added
- Check Apple Developer portal Services ID configuration
- Ensure redirect URLs match exactly

### Sync not working
- Verify you're authenticated (check `AuthManager.isAuthenticated`)
- Check network connectivity
- Look for errors in Xcode console

### Sharing not working
- Verify `task_shares` and `contacts` tables exist (migration 005)
- Ensure RLS policies are enabled for `task_shares` and `contacts`
- Verify `contacts.contact_phone` exists (migration 006)
- Ensure `user_profiles.email` exists for share lookup
- Verify `device_tokens` table exists (migration 010)
- Verify `resolve_share_recipient_trigger` exists (migration 010)

### Push notifications not arriving
- Confirm APNs secrets are set in Edge Functions
- Verify Edge Function deployed: `push-share-notification`
- Confirm DB webhook exists for `task_shares` INSERT
- Confirm device token stored in `device_tokens`

### Grocery templates missing
- Verify `grocery_stores` table exists (migration 003)
- Ensure `checklist_items` column exists on `tasks`

## Next Steps After Setup

Once auth is working:
1. Test creating tasks (should sync to Supabase)
2. Test editing/deleting tasks
3. Test pull-to-refresh sync
4. Test on multiple devices (same account) to verify cloud sync
5. Test sharing flow (Share icon → email invite)
6. Test grocery templates (Profile → Store Templates)

---

*Setup guide created 2026-02-06*
