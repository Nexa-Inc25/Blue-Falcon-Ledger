# App Store Rejection — Resubmission Checklist (June 9, 2026)

Submission ID: `14c7eea8-cd4e-409b-94d9-a2eb43838535`  
Version: 1.0 (2)

Apple flagged **three issues**. Do every item below before uploading a new build.

---

## 1. Guideline 2.3.2 — IAP promotional image (App Store Connect only)

**Problem:** The promotional image for your In-App Purchase is an in-app screenshot.

**Fix (pick one):**
- **Easiest:** App Store Connect → your app → **In-App Purchases** → open each subscription → **Delete** the promotional image if you are not actively promoting it on the App Store.
- **Or:** Replace it with a **custom graphic** (not a screenshot) that represents BFL Pro — e.g. icon + “Unlimited contract audits” on a branded background. 1024×1024 or per Apple’s IAP promo specs.

No code change required.

---

## 2. Guideline 3.1.2(c) — Terms of Use (EULA) + Privacy Policy links

**Problem:** App Store metadata is missing a functional **Terms of Use** link. Privacy policy must also be a **working page** (not a “Coming Soon” site).

### A. Host the privacy policy (required before resubmit)

1. Upload `docs/privacy.html` from this repo to your web host.
2. It loads at: **https://nexa-inc25.github.io/Blue-Falcon-Ledger/privacy.html** (GitHub Pages, `main` / `/docs`).
3. Confirm both links open on your phone:
   - Privacy: your hosted `privacy.html`
   - Terms: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

### B. App Store Connect metadata

**Privacy Policy URL field:** paste your working privacy policy URL.

**App Description** — add this block at the **end** of the description:

```
SUBSCRIPTION
BFL Pro is an auto-renewable subscription (monthly or yearly) for unlimited BFL Cloud analysis and agreement chat. Payment is charged to your Apple Account. Subscriptions renew automatically unless canceled at least 24 hours before the end of the period. Manage or cancel in Settings → Apple ID → Subscriptions.

Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://nexa-inc25.github.io/Blue-Falcon-Ledger/privacy.html
```

(Use your real privacy URL if different.)

**Optional:** App Store Connect → App Information → **License Agreement** → select Apple’s standard EULA (same link as above).

### C. In the app (already updated in code)

Paywall and Settings include **Terms of Use** and **Privacy Policy** links plus subscription renewal disclosure text.

---

## 3. Guideline 2.1(b) — Subscription plans not available during review

**Problem:** Reviewer on iPad saw no purchasable plans. The old Release build showed *“Plans aren't available yet. Once the subscription is set up in App Store Connect…”* when StoreKit returned no products.

### A. App Store Connect — subscription setup (most common root cause)

Confirm **all** of the following:

1. **Paid Apps Agreement** — Account Holder signed in App Store Connect → **Business** → Agreements.
2. **Subscription group** exists with products:
   - `io.nexaus.bfc.pro.monthly` — auto-renewable, 1 month
   - `io.nexaus.bfc.pro.yearly` — auto-renewable, 1 year
3. Product IDs match **exactly** (case-sensitive) what’s in `SubscriptionService.swift`.
4. Each subscription has **localization** (display name, description) and **pricing** for at least one territory.
5. Introductory offer (7-day free trial) is configured if you advertise a trial.
6. Subscription status is **Ready to Submit** (not Missing Metadata).
7. On the **app version** you submit, under **In-App Purchases and Subscriptions**, both products are **included** on the version.
8. **Remove** any IAP promotional screenshot (issue #1) or replace with a proper graphic.

### B. Sandbox test before resubmitting

1. Create a **Sandbox Apple ID** (Users and Access → Sandbox).
2. On a real device (or iPad simulator with StoreKit testing): sign into Sandbox in Settings → App Store.
3. Open the app → Settings → **Go Pro** — both plans must appear with prices.
4. Complete a sandbox purchase and **Restore Purchases**.

### C. Code changes in this repo

- Paywall retries StoreKit product loading (cold-start / review iPad).
- Release build no longer shows the “not set up in App Store Connect” message.
- Subscription **length** shown on each plan (e.g. “$7.99 per 1 month”).
- Legal footer on paywall + Settings.

Upload **new build** (increment build number to 3) after ASC fixes.

---

## Reply to App Review (paste in Resolution Center)

```
We addressed all three issues:

1. Promotional image: Removed [or replaced] the In-App Purchase promotional image in App Store Connect.

2. Terms of Use / Privacy: Added Terms of Use (Apple standard EULA) and Privacy Policy links to the App Store description and Privacy Policy URL field. The app paywall and Settings include functional links to both.

3. Subscriptions: Verified Paid Apps Agreement, subscription metadata, and attached both auto-renewable products to this app version. Tested sandbox purchase on iPad — both monthly and yearly plans load and purchase successfully.

Privacy Policy: https://nexa-inc25.github.io/Blue-Falcon-Ledger/privacy.html
Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
```

Attach a **screen recording** showing: Settings → Go Pro → plans visible → sandbox purchase or restore (as Apple requested).

---

## App Review Information (Notes for next submission)

```
Sandbox test account: [your sandbox Apple ID email]
How to reach paywall: Sign in → Home (gear) Settings → Go Pro, or use BFL Cloud until free uses run out.
Subscriptions: BFL Pro Monthly and Yearly — product IDs io.nexaus.bfc.pro.monthly and io.nexaus.bfc.pro.yearly.
Privacy: https://nexa-us.io/privacy.html
Terms (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
```
