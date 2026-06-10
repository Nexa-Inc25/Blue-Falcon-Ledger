# CLAUDE.md - BFC (Brother Fucker Calculator) — Opus 4.8 Optimized

## Project Goal
Build an extremely simple, rugged, blue-collar iOS app for Journeyman Linemen. 
The app helps them track employers, labor agreements, hours, per diem, and detect when companies are "brother fucking" them on pay. 
Maximum usability with gloves on. Dark theme. Large tap targets. Zero fluff.

## Opus 4.8 Rules (Follow These Strictly)
- Use **xhigh effort** on any complex or multi-step task.
- Always start significant features with a **clear plan + numbered acceptance criteria**.
- Use **positive instructions** ("Build X using this pattern...") instead of negative ones.
- Self-verify your output against the requirements before presenting.
- Prefer fresh sessions when context gets heavy. CLAUDE.md carries the persistent rules.
- Detailed scope + file paths = much better results. Be specific.

## Architecture & Coding Standards
- Feature-first structure (see below)
- MVVM with `@Observable`
- SwiftUI only (latest patterns)
- Swift 6 strict concurrency
- `async/await` everywhere
- Prefer value types (structs)
- Use `guard` for early exits
- Extract views when they exceed ~100-120 lines
- All data models in `Models/`
- Services in `Services/`

## UI/UX Rules (Non-Negotiable)
- Dark theme first (`Theme.background`, `Theme.surface`)
- Large tap targets (minimum 50-56pt)
- Bold, high-contrast text (body ≥17pt)
- Big, obvious buttons
- Minimal navigation — bottom tab bar preferred
- No unnecessary animations
- Rugged, functional, blue-collar feel
- Voice input must be very prominent when logging hours

## Folder Structure

```
BFC/
├── App/
├── DesignSystem/          # Theme, Components, Formatting
├── Models/
├── Services/              # Auth, LLM, PDF, Speech, Analysis
├── Features/
│   ├── Auth/
│   ├── Home/
│   ├── Employers/         # List + Add/Edit + Detail
│   ├── HoursPay/          # Logging + uploads
│   └── Analysis/
└── Utils/
```

> On disk the logging/uploads folder is `Features/Hours/`, shared helpers live in
> `Features/Shared/`, and there are also `Features/Chat/` (agreement Q&A) and
> `Features/Settings/`. The `BFC.xcodeproj` uses **Xcode synchronized file groups** —
> adding a file anywhere under `BFC/` automatically includes it in the target.

## Key Behaviors for This App
- Labor Agreement PDF → full text extraction + permanent storage
- LLM Analysis must be strict and detailed when checking pay vs agreement
- Use clear, direct, blue-collar language in analysis results
- Support both cloud LLM + on-device fallback
- Manual hours + voice-to-text (Speech framework)
- Per diem tracking tied to logged days

## Priority Order (Current)
1. Employers feature (Add/Edit + PDF labor agreement upload + text extraction)
2. Hours & Pay logging (daily hours + voice input + paystub upload)
3. Analysis engine (LLM + labor agreement cross-check)
4. Polish & testing

## What Good Looks Like
- Simple enough that a lineman can use it with one hand while wearing gloves
- Analysis that actually catches underpayment
- Clean, maintainable code that follows Apple guidelines

Follow these rules on every task. When in doubt, make it simpler and more rugged.

## Core Data Models (SwiftData)
`UserProfile`, `Employer`, `LaborAgreement`, `WorkDay`, `PayPeriod`, `PayDocument`,
`ChatMessage`, `AnalysisResult`. Money is `Decimal`, hours are `Double`, dates are `Date`.

## Service Abstractions (so the app builds & runs offline with zero setup)
- **Auth** — `AuthService` protocol. `LocalAuthService` (default, Keychain-backed,
  offline). `FirebaseAuthService` compiled only when the Firebase SPM package is added
  (`#if canImport(FirebaseAuth)`); to enable, add `firebase-ios-sdk`, drop
  `GoogleService-Info.plist` in `Resources/`, set `AppSettings.authBackend = .firebase`.
- **LLM** — `LLMService` protocol, swappable in Settings: `.appleOnDevice`
  (Foundation Models, iOS 26, private, default), `.claude`, `.openai`, `.grok`
  (HTTP via URLSession; API key in Keychain). The pay-analysis prompt includes the
  **full labor-agreement text** and audits ST/OT/DT, differentials, and per diem strictly.
- **PDF** — `PDFTextExtractor`: PDFKit embedded text first, Vision OCR fallback for scans.
- **Speech** — `SpeechTranscriber`: `SFSpeechRecognizer` + `AVAudioEngine`, on-device when supported.

## Security
- API keys & credentials: **Keychain only** (`KeychainStore`), never UserDefaults.
- SwiftData store + file blobs rely on iOS Data Protection. No analytics/trackers.

## Build / Run
```
xcodebuild -project BFC.xcodeproj -scheme BFC -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```
Open in Xcode and run on a simulator or device. Deployment target: iOS 26.
