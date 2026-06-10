# Blue Falcon Ledger Privacy Policy

_Last updated: June 2026_

Blue Falcon Ledger ("the app") is built for journeyman linemen to track employers, hours,
per diem, credentials, and to ask questions about their labor agreement. This policy
explains what the app does with your information.

## What we store
Everything you enter — employers, labor agreements, logged hours, pay documents,
credentials, and chat history — is stored **locally on your device** using Apple's
on-device storage and Keychain, encrypted at rest. We do not run a database of your
personal data, and your account for the on-device sign-in never leaves your phone.

## What is sent off the device
To answer questions and analyze pay, the app sends the **relevant portions of your labor
agreement and the pay/hours data needed for that question** to the AI model that powers
the analysis:
- **BFL Cloud:** the request goes to our proxy server, which forwards it to Anthropic
  (Claude) and returns the answer. The proxy does not store your contract or pay data.
- **Your own API key (optional):** the request goes directly from your device to the
  provider you chose (Anthropic, OpenAI, or xAI).
- **On-device model:** nothing is sent off the device.

Your stored credentials (CPR card, DOT physical, dues receipt, etc.) are **never** sent
off the device.

This data is used only to generate your answer. It is not sold, not used for advertising,
and not used to identify you.

## What we do NOT do
- No analytics or tracking SDKs.
- No advertising.
- No selling or sharing of personal data.

## Your control
Delete an employer, document, credential, or your data at any time inside the app;
removing the app deletes all locally stored data.

## Not legal advice
Blue Falcon Ledger is an informational tool and can make mistakes. It is not legal advice.
Always verify important pay and contract questions with your local union hall or business
agent.

## Contact
Questions about this policy: mike.v.moore@protonmail.com
