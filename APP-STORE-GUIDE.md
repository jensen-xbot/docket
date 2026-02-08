# Docket: TestFlight & App Store Publishing Guide

## Part 1: TestFlight (Beta Testing)

TestFlight lets you distribute Docket to up to 10,000 testers without going through App Store review (for internal testers). Your wife and anyone else can install it directly from the TestFlight app.

### Prerequisites

- **Apple Developer Program** membership ($99/year) — enroll at [developer.apple.com/programs](https://developer.apple.com/programs)
- **Xcode** installed with your Apple ID signed in (Xcode > Settings > Accounts)
- **App Store Connect** access (comes with your Developer Program membership)

### Step 1: Configure Signing in Xcode

1. Open `Docket.xcodeproj` in Xcode
2. Select the **Docket** target > **Signing & Capabilities** tab
3. Set **Team** to your Apple Developer team
4. Ensure **Bundle Identifier** is `com.jensen.docket`
5. Check "Automatically manage signing" — Xcode will create provisioning profiles for you

### Step 2: Archive the App

1. In Xcode, set the build destination to **Any iOS Device (arm64)** (not a simulator)
2. Go to **Product > Archive**
3. Wait for the archive to complete — the Organizer window will open automatically

### Step 3: Upload to App Store Connect

1. In the **Organizer** window, select your archive
2. Click **Distribute App**
3. Choose **App Store Connect** > **Upload**
4. Follow the prompts (leave default options)
5. Click **Upload** — Xcode will validate and upload the build

### Step 4: Set Up the App in App Store Connect

1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. Click **My Apps** > **+** > **New App**
3. Fill in:
   - **Platform:** iOS
   - **Name:** Docket
   - **Primary Language:** English
   - **Bundle ID:** com.jensen.docket
   - **SKU:** docket-ios (any unique string)
4. Click **Create**

### Step 5: Add TestFlight Testers

1. In App Store Connect, go to your app > **TestFlight** tab
2. Wait for the uploaded build to finish processing (~5-15 minutes)
3. The build will appear under **iOS Builds**

**For internal testers (up to 25 people, no review needed):**
1. Go to **Internal Testing** > **App Store Connect Users**
2. Click **+** next to the group
3. Add your wife's Apple ID email
4. She'll receive an email invite to install via the TestFlight app

**For external testers (up to 10,000 people, requires beta review):**
1. Go to **External Testing** > create a new group
2. Add tester emails
3. Fill in basic test information (what to test, contact info)
4. Submit for Beta App Review (~24 hours)

### Step 6: Install on Tester's Device

1. Tester downloads the **TestFlight** app from the App Store
2. Tester opens the invite email and taps **Accept**
3. Docket appears in TestFlight — tap **Install**
4. The app installs and works like a normal app

### Updating TestFlight Builds

1. Increment the **Build Number** in Xcode (Target > General > Build)
2. Archive again (Product > Archive)
3. Upload to App Store Connect
4. TestFlight testers are automatically notified of the new build

---

## Part 2: App Store Publication

### Prerequisites Checklist

Before submitting, prepare the following:

- [ ] **App Icon** — 1024x1024 PNG, no transparency, no rounded corners (Apple adds them)
- [ ] **Screenshots** — Required sizes:
  - 6.7" display (iPhone 15 Pro Max / 16 Pro Max): 1290 x 2796 px
  - 6.1" display (iPhone 15 Pro / 16 Pro): 1179 x 2556 px
  - Optional: 6.9" (iPhone 16 Pro Max), 5.5" (iPhone 8 Plus)
- [ ] **App Description** — Short and long description of what Docket does
- [ ] **Keywords** — Up to 100 characters, comma-separated (e.g., "tasks, to-do, groceries, checklist, productivity")
- [ ] **Category** — Productivity
- [ ] **Privacy Policy URL** — Required (host a simple page explaining data collection)
- [ ] **Support URL** — A webpage or email for user support
- [ ] **App Store Connect metadata** filled in (see below)

### Pre-Submission Code Changes

1. **Replace placeholder App Store URL** in `ShareTaskView.swift`:
   - Find: `https://apps.apple.com/app/docket/id0000000000`
   - Replace with your real App Store URL after the app is created in App Store Connect

2. **Verify push notification setup:**
   - APNs key uploaded to Supabase dashboard
   - `Docket.entitlements` has push notification entitlement
   - Provisioning profile includes push notification capability

3. **Verify bundle ID and version:**
   - Target > General > Version: `1.0.0` (or your chosen version)
   - Target > General > Build: `1` (increment for each upload)

### Step 1: Prepare App Store Connect Listing

1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com) > your app
2. Go to **App Store** tab > **App Information**:
   - Name: Docket
   - Subtitle: "Simple, fast task management" (30 char max)
   - Category: Productivity
   - Content Rights: "Does not contain third-party content"
3. Go to **Pricing and Availability**:
   - Price: Free
   - Availability: All territories (or select specific ones)

### Step 2: Fill In Version Details

1. Go to your app > **iOS App** > **1.0 Prepare for Submission**
2. Upload **screenshots** for each required device size
3. Fill in:
   - **Promotional Text** (optional, can be updated without a new build)
   - **Description:** What Docket does, key features
   - **Keywords:** tasks, to-do, groceries, checklist, productivity, shopping, organize
   - **Support URL**
   - **Marketing URL** (optional)

### Step 3: App Review Information

1. **Sign-In Required:** Yes — provide a demo account or explain Sign in with Apple
2. **Contact Information:** Your name, phone, email (for Apple reviewers only)
3. **Notes:** Explain any features that might not be obvious to reviewers
4. Example notes:
   ```
   Docket is a task management app. Users sign in with Apple.
   Key features: create tasks, grocery checklists, share tasks with contacts.
   No demo account needed — reviewers can create an account via Sign in with Apple.
   ```

### Step 4: Privacy Details

Apple requires you to declare what data your app collects:

1. Go to **App Privacy** section
2. Declare the following data types:
   - **Contact Info > Email Address** — used for account creation
   - **Contact Info > Name** — used for profile display
   - **Contact Info > Phone Number** — optional profile field
   - **Identifiers > User ID** — Supabase auth user ID
3. For each, specify:
   - **Data use:** App Functionality
   - **Linked to user:** Yes
   - **Tracking:** No

### Step 5: Submit for Review

1. Select your uploaded build under **Build** section
2. Click **Add for Review**
3. Click **Submit to App Review**
4. Status changes to **Waiting for Review**

### Step 6: App Review Timeline

- **Typical review time:** 24-48 hours
- **Possible outcomes:**
  - **Approved** — App goes live on the App Store (or on your chosen release date)
  - **Rejected** — Apple provides specific reasons; fix and resubmit
- **Common rejection reasons:**
  - Crashes on launch
  - Broken sign-in flow
  - Missing privacy policy
  - Incomplete metadata or screenshots

### Step 7: Post-Launch

1. Update the App Store URL in your code for the share feature
2. Monitor **App Store Connect > Analytics** for downloads and usage
3. Respond to user reviews
4. For updates: increment version/build, archive, upload, submit

---

## Quick Reference: Key Accounts & URLs

| Service | URL |
|---------|-----|
| Apple Developer | [developer.apple.com](https://developer.apple.com) |
| App Store Connect | [appstoreconnect.apple.com](https://appstoreconnect.apple.com) |
| Supabase Dashboard | [supabase.com/dashboard](https://supabase.com/dashboard) |
| TestFlight (tester) | Download from App Store on iPhone |

## Quick Reference: Xcode Archive & Upload

```
1. Set destination: Any iOS Device (arm64)
2. Product > Archive
3. Organizer > Distribute App > App Store Connect > Upload
4. Wait for processing in App Store Connect (~5-15 min)
```
