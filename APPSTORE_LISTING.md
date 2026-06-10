# BFC — App Store Connect Listing (copy-paste)

Public fields only. Keep the full profane name out of all store metadata (App Review
guideline 1.1.4). Home-screen icon name stays "BFC".

## Name (≤30 chars, globally unique)
Blue Falcon Ledger

## Subtitle (≤30 chars)
Know what you're owed

## Bundle ID
io.nexaus.bfc

## Primary category / Secondary
Finance / Productivity

## Promotional text (≤170 chars, editable anytime without review)
Upload your labor agreement, log your hours, and let BFC check your pay and benefits
against the contract — so you catch what you're owed.

## Keywords (≤100 chars, comma-separated)
lineman,IBEW,union,per diem,overtime,pay,hours,paystub,NEAP,wages,journeyman,contract

## Description
Blue Falcon Ledger helps journeyman linemen keep the company honest.

Track who you work for, log your hours (by voice if your hands are full), and upload your
labor agreement, pay stubs, NEAP statements, and foreman time sheets. Then let BFC read
your actual contract and check whether you were paid right.

WHAT IT DOES
• Reads your labor agreement (PDF) and answers plain-English questions about it — overtime,
  per diem, travel, meal penalties, classifications, and more.
• Audits a pay period against the contract and flags where you might be getting shorted —
  pay AND benefits (pension/annuity like NEAP, health & welfare like Lineco).
• Uses the rate in effect for the dates you worked, and the rules in YOUR agreement — not
  generic assumptions.
• Log hours fast: straight time, overtime, double time, per diem, and missed meals.
• Voice-to-text for logging in the field.

BUILT FOR THE JOB
• Dark, simple, big buttons — usable with gloves on.
• Your contracts and pay data stay on your phone.

BFC is a helper, not legal advice, and it can make mistakes. Always verify anything
important with your local union hall or business agent before acting on it.

SUBSCRIPTION
BFL Pro is an auto-renewable subscription (monthly or yearly) for unlimited BFL Cloud analysis and agreement chat. Payment is charged to your Apple Account. Subscriptions renew automatically unless canceled at least 24 hours before the end of the period. Manage or cancel in Settings → Apple ID → Subscriptions.

Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://nexa-us.io/privacy.html

## Support URL (required — must be a working page)
https://nexa-us.io        (or any page/Notion/email-contact page you control)

## Marketing URL (optional)
(leave blank or your site)

## Privacy Policy URL (required to submit; needed for external TestFlight)
https://nexa-us.io/privacy.html
Upload `docs/privacy.html` from this repo — must be a working page before resubmitting.
See APPSTORE_RESUBMIT.md for the full rejection fix checklist.

## Age rating
4+ (no objectionable content in the app itself)

## App Privacy (App Store Connect → App Privacy)
- Data collected: none for tracking/advertising.
- "Data used to provide the service": contract/pay text is sent to the AI provider
  (your proxy → Claude) to generate answers; not linked to identity, not used for tracking.

---

## TestFlight "What to Test" (beta notes for testers)
Thanks for testing Blue Falcon Ledger. Please try:
1) Add your current employer and upload your labor agreement (PDF).
2) Ask the agreement questions in Chat — e.g. "what's the OT rule?", "what's the per diem?",
   "what's the foreman rate?". Tell me if any answer is wrong or misses something.
3) Log a few days of hours (try the voice button). Mark any missed meals.
4) Upload a pay stub and/or NEAP statement, then tap "Analyze This Pay Period."
5) Tell me if the numbers, rates, or the year it used look wrong for your contract.

No setup needed — the AI is built in. Everything stays on your phone.
Feedback: mike.v.moore@protonmail.com
