# TestFlight & App Store Resubmission — Blue Falcon Ledger

Use this after Apple's June 9, 2026 rejection. Full checklist: **`APPSTORE_RESUBMIT.md`**.

## Current app identity

| Field | Value |
|-------|--------|
| App Store name | Blue Falcon Ledger |
| Display name (home screen) | BFL |
| Bundle ID | `io.nexaus.bfc` |
| Version | 1.0 |
| Build | 3 (increment before each new upload) |
| Subscription IDs | `io.nexaus.bfc.pro.monthly`, `io.nexaus.bfc.pro.yearly` |

---

## Before you upload build 3

### 1. App Store Connect (metadata — no new build required)

Do these **before** or **with** the new upload:

1. **Delete IAP promotional images**  
   App Store Connect → Blue Falcon Ledger → **Subscriptions** → each product → remove the promotional image (Apple rejected it for being an app screenshot).

2. **Privacy Policy URL**  
   Host `docs/privacy.html` at a working URL (e.g. `https://nexa-us.io/privacy.html`).  
   Paste that URL into App Store Connect → **App Privacy** → Privacy Policy URL.

3. **App Description**  
   Append the subscription + legal block from `APPSTORE_LISTING.md` (Terms of Use + Privacy links).

4. **Subscriptions attached to version**  
   On version **1.0**, under **In-App Purchases and Subscriptions**, include both monthly and yearly products. Status must be **Ready to Submit**.

5. **Paid Apps Agreement**  
   Account Holder → **Business** → Agreements → signed.

### 2. Sandbox test (required)

1. Create a **Sandbox Apple ID** (Users and Access → Sandbox Testers).
2. On an **iPad** (Apple reviewed on iPad): Settings → Developer/App Store → sign into Sandbox.
3. Install the new build → sign in → Home → **Settings (gear)** → **Go Pro**.
4. Confirm **both plans show prices** and you can tap to purchase (sandbox).
5. Record a **30–60s screen video** of this for App Review.

### 3. Build & upload

1. Confirm `CURRENT_PROJECT_VERSION` is **3** in Xcode (General → Build).
2. **Product → Archive** (Any iOS Device).
3. **Distribute → App Store Connect** (not Internal Only if submitting for App Review).
4. Wait for processing in TestFlight.

---

## TestFlight: what to change for Apple re-review

TestFlight alone does **not** re-trigger App Review. You must **submit for review** again.

### Step A — New build on TestFlight

1. App Store Connect → **TestFlight** → wait for build **1.0 (3)** to finish processing.
2. Optional: add internal testers and smoke-test on iPad.

### Step B — Submit for App Review (this is what triggers re-review)

1. App Store Connect → **Distribution** → **iOS App** → version **1.0**.
2. Select build **(3)** (not the rejected build 2).
3. **In-App Purchases and Subscriptions** — both products checked on this version.
4. **App Review Information:**
   - Notes (paste from `APPSTORE_RESUBMIT.md`):
     ```
     Sandbox test account: [your sandbox email]
     Paywall: Sign in → Home → Settings (gear) → Go Pro
     Subscriptions: io.nexaus.bfc.pro.monthly, io.nexaus.bfc.pro.yearly
     Privacy: https://nexa-us.io/privacy.html
     Terms: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
     ```
   - Attach **screen recording** of paywall with plans loading on iPad.
5. Click **Add for Review** → **Submit to App Review**.

### Step C — Reply in Resolution Center

Open the rejection message (Submission `14c7eea8-cd4e-409b-94d9-a2eb43838535`) → **Reply** with the text in `APPSTORE_RESUBMIT.md` and mention build **3**.

---

## Internal vs external TestFlight

| Track | Review needed? | Use when |
|-------|----------------|----------|
| **Internal** | No | Quick team smoke test after upload |
| **External** | Beta App Review | Public link for linemen testers |
| **App Store** | Full App Review | **Required for re-review after rejection** |

After rejection fixes, you need **App Store submission** (Step B), not just a new TestFlight internal build.

---

## Pre-upload code checklist

- [ ] `docs/privacy.html` hosted and URL loads on phone
- [ ] Paywall shows Terms + Privacy links
- [ ] Sandbox: both subscription plans load on iPad
- [ ] IAP promo images removed in App Store Connect
- [ ] Description includes EULA + Privacy URLs
- [ ] Tests: `xcodebuild -project BFC.xcodeproj -scheme BFC -destination 'platform=iOS Simulator,name=iPhone 17' test`

## Repo

https://github.com/Nexa-Inc25/Blue-Falcon-Ledger
