# Release checklist

Run this for every App Store version. Copy it into the version's Notion milestone (or a
`Release/<version>.md` note) and tick it there, so this file stays a clean template.

Order matters: **server first, then the app.** The App Store build talks to whatever Railway is
running the day a reviewer opens it.

---

## 1. Decide the version

- [ ] Pick the version: **MARKETING_VERSION** in the target's build settings (2.5.0 today).
      Patch (2.4.1) for fixes only, minor (2.5.0) for new features.
- [ ] Bump **CURRENT_PROJECT_VERSION** (the build number) for every upload, including a
      re-upload of the same version.
- [ ] Set the Notion milestone on every ticket going out in this version.

## 2. Code is finished, not half-way

- [ ] Every ticket in the milestone is **Done** in Notion with its commit SHA(s), or moved out.
- [ ] `git status` is clean in **both** repos (app and `Bullish Square API`). Anything uncommitted
      gets committed (with approval) or reverted. Xcode archives the working copy, not the last
      commit.
- [ ] `Pods/` is unchanged unless the Podfile changed on purpose. If Xcode offers "Update to
      recommended settings" for **Pods**, decline (it rewrote 112 deployment targets on 25 Nov 2026).
- [ ] No `TODO`, debug `print` floods, or test switches left in the version's changes:
      `git diff <last release tag>..HEAD`.
- [ ] Both repos are pushed (Javier pushes).

## 3. Server (Railway), before the app

- [ ] API pushed to `main`. Railway deploy finished and the log shows no startup errors.
- [ ] API tests: `npm test` passes, apart from the 2 known App Check tests.
- [ ] New or changed **Railway variables** are set. Compare the README's variables table with
      Railway. Ones added recently: `TREND_FLIPS_TIME`, `SPARK_TTL_SECONDS`,
      `SPARK_LONG_TTL_SECONDS`, `YFAPI_MONTHLY_LIMIT`, `EMAIL_WATCHLIST_TIME`.
- [ ] `MINIMUM_APP_VERSION`: raise it **only** if older apps would break against the new server.
      Usually leave it.
- [ ] No `QUOTA LOW` in Railway's log for YFAPI, Mboum, news or logos.
- [ ] Scheduled jobs ran on the last trading day: `Trend flips:` (with `theses …`) and `Email:`
      lines in the log.

## 4. Firebase

- [ ] **Firestore rules** (console only) cover every new collection:
  - [ ] Users' own data readable and writable only by them (`users/{uid}/**`, `theses/{uid}/items`).
  - [ ] Server-only collections have no rule, so phones are denied: `dailyCloses`,
        `trendStates`, `trendEvents`, `emailRuns`, `botRuns`, `botDrafts`.
  - [ ] Saved with no catch-all rule.
- [ ] Any new composite or collection-group index the console asked for is built.
- [ ] **App Check: never click Enforce.** Leave it as it is.

## 5. Build and test

- [ ] Open `Bullish Square.xcworkspace` (never the `.xcodeproj`), Clean Build Folder, build.
- [ ] Run the **on-device repro steps** of every ticket in the version (they're in each commit
      message and Notion ticket).
- [ ] The basics, on a real phone:
  - [ ] Fresh install, signed out: Watchlist, search, chart, Markets, News all work.
  - [ ] Sign up a new account, verify the email (Gmail, not Hotmail/Outlook).
  - [ ] Sign in on a second phone: watchlists and theses come back.
  - [ ] Sign out: nothing of the account is left on screen.
  - [ ] **Delete Account** on a test account, then check the console: `users/{uid}` (and its
        subcollections), `theses/{uid}`, `profiles/{uid}`, `emailSubscriptions/{uid}` and the
        Auth user are all gone.
  - [ ] Notifications: permission prompt, Settings switches, one Community push, one trend or
        thesis push (simulator `.apns` files in `Research/product/` for the tap routing).
  - [ ] Dark mode only (forced), Dynamic Type at a large size, VoiceOver on the new screens.

## 6. Documents

- [ ] `CLAUDE.md`: new invariants, traps or hazards learned in this version.
- [ ] `PROJECT.md` (local): status, the endpoint-to-caller map (§3), data model, open issues.
- [ ] API `README.md`, `docs/EMAIL.md` (and `docs/BOTS.md` if bots changed).
- [ ] `Research/product/SPEC.md` (local): release status table, decisions, "not built yet" notes.
- [ ] **Features guide PDF** (`Research/product/Bullish-Square-Stock-Features-Guide.pdf`):
      add the new features and any changed rule or number. Keep its **source** (HTML or Markdown)
      next to the PDF. The first one's source lived in a temp folder and is gone, so the next
      update rebuilds it once and saves it there.
- [ ] Promotional feature summary (the plain-language one for images): new features and any
      changed wording.

## 7. Website (jdevit.com)

- [ ] **Privacy policy**: every new kind of data the app stores or sends, and how it's deleted.
      Added recently: theses and notes (BS-318), check-in answers (BS-319), exit plans with goal
      dates (BS-320), the trend-alert log (BS-313), and the daily email (BS-298).
- [ ] Terms of Service and Disclaimer: still match what the app does (alerts, check-ins and
      exit-plan reminders are states and reminders, **not advice**).
- [ ] The links in Profile still open the right pages (privacy, terms, disclaimer, contact).

## 8. App Store Connect

- [ ] **What's New**: plain words, features first, no claims of beating the market.
- [ ] Description, keywords and promotional text: updated for new features.
- [ ] **Screenshots** show the current design and the new features (6.9" required; 6.5" if
      still listed). Same wording as the promotional summary.
- [ ] **App Privacy** label matches the policy. For example, theses and notes are
      *User Content → Other User Content*, linked to the user, not used for tracking.
- [ ] Support URL and marketing URL work.
- [ ] Release option: manual or automatic after approval; phased release on or off.

## 9. After release

- [ ] Tag both repos (`git tag v2.5.0`). Javier pushes tags.
- [ ] Notion: milestone and its tickets set to **Shipped**.
- [ ] Watch **Crashlytics** and Railway logs for the first 2–3 days: crashes, `QUOTA LOW`,
      failed jobs, push errors.
- [ ] Read App Store reviews and reply to the first week's.
- [ ] Note anything this checklist missed, and add it here.
