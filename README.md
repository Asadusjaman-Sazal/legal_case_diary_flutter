# Legal Case Diary

**Legal Case Diary (লিগ্যাল কেস ডায়েরি) is a secure, bilingual, offline-first mobile case-management app for individual lawyers and law firms in Bangladesh.** It digitizes the traditional cause-list diary so practitioners can organize cases, track hearing dates, manage notes and references, collaborate with chamber members, and keep working reliably without an internet connection.

## Product Overview

Legal Case Diary is designed as a digital clerk and ledger for Bangladeshi legal practitioners. The application combines fast local data access with optional premium cloud synchronization, giving individual lawyers a dependable single-device workflow and law firms a controlled multi-user workspace.

The interface supports Bengali and English, follows Bangladesh-specific legal workflows and date conventions, and uses the high-density **Justice Ledger** visual system optimized for mobile devices, including low-memory Android phones.

## Core Features

- **Complete case diary:** Manage active, upcoming, overdue, disposed, and all cases from focused case lists.
- **Daily Cause List:** Review hearings by date with calendar-based case-count indicators.
- **Case details and history:** Track parties, courts, case types, representation roles, steps, hearing dates, and date-change history.
- **Notes and references:** Maintain searchable, contextual notes, precedents, and citations.
- **Offline-first operation:** Continue viewing and editing data without connectivity using an encrypted local database.
- **Secure synchronization:** Premium users receive cloud backup, multi-device sync, and structured conflict handling through Supabase.
- **Firm collaboration:** Owners can invite associates with secure single-use codes and manage role-based permissions.
- **Bilingual experience:** Bengali and English localization with Bangladesh civil-date handling and `DD/MM/YYYY` display.
- **Reminders and documents:** Schedule hearing notifications and generate printable, shareable case-list PDFs.
- **Backup and recovery:** Export versioned, validated, encrypted backups with safe restore workflows.
- **Localized subscriptions:** Free individual use for up to 50 non-deleted cases, with monthly and annual premium plans paid through supported mobile financial services.

## Architecture

The planned mobile application uses an MVVM and repository-based architecture:

```text
Flutter UI
  → Riverpod ViewModels
    → Repositories
      ├─ Drift + SQLCipher local database
      └─ Supabase PostgreSQL, Auth, Realtime, and RPCs
```

The local database is the immediate source for responsive UI and offline work. Premium synchronization uses a serialized mutation queue, optimistic concurrency, idempotency receipts, per-table composite pull cursors, tombstones, and structured conflict reconciliation to prevent skipped updates or accidental data resurrection.

## Technology Stack

- **Client:** Flutter and Dart
- **State management:** Riverpod
- **Navigation:** GoRouter
- **Local persistence:** Drift with SQLCipher-compatible encryption
- **Backend:** Supabase PostgreSQL, Auth, Realtime Broadcast, and RPCs
- **Localization:** `flutter_localizations`, `intl`, and ARB resources
- **Platforms:** Android and iOS, with platform abstractions supporting a future Windows port

## Security and Data Integrity

Security is part of the application architecture rather than an optional layer:

- OS-backed storage protects local encryption keys.
- Local databases and exported recovery archives are encrypted.
- Supabase Row-Level Security isolates individual and firm data.
- Server RPCs enforce subscriptions, permissions, mutation ordering, and optimistic concurrency.
- Single-use hashed invite codes protect firm onboarding.
- Soft deletion and retained tombstones prevent deleted records from returning during sync.
- Immutable audit records protect administrative payment approvals and case-history events.

## Subscription Model

| Plan | Intended use | Included capabilities |
|---|---|---|
| Free | Individual lawyers | Up to 50 non-deleted cases, local-only operation, Daily Cause List, client history, and manual local backup |
| Monthly Premium | Individuals and firms | Unlimited cases, cloud backup, multi-device synchronization, and firm collaboration for **৳100/month** |
| Annual Premium | Individuals and firms | All premium capabilities for **৳1,000/year** |

Firm access is tied to the owner&apos;s premium entitlement. If the subscription expires, cloud synchronization pauses for all firm members while local data remains available.

## Design System

The **Justice Ledger** design language uses an ink-dark primary palette, action blue, parchment-white backgrounds, restrained status colors, and flat stationery-inspired surfaces. English typography uses Manrope, Inter, and IBM Plex Sans according to content type, while Bengali content uses Tiro Bangla with script-appropriate line height.

Performance is a first-class requirement. The app avoids real-time backdrop filters and uses low-cost visual alternatives to remain smooth on representative 2 GB Android devices.

## Implementation Status

The project is being delivered incrementally from the authoritative plan in [`docs/implementation_plan.md`](docs/implementation_plan.md). The plan defines product behavior, screen specifications, architecture, database contracts, synchronization semantics, security controls, coding standards, and the full automated and manual verification suite.

Current implementation status should be tracked in `docs/currentlyWorking.md`, with every code change recorded in `docs/version_history.md` as development progresses.

## Quality and Verification

The verification strategy covers:

- Flutter unit, repository, DAO, sync, timestamp, schema, and security tests
- Server-side PostgreSQL and RLS verification
- Offline authentication and reconnect behavior
- Multi-device concurrency and structured conflict handling
- Extended-offline recovery and encrypted archive validation
- Low-memory PDF generation and notification reliability
- Firm subscription, permission, invite, and payment-approval workflows
- Complete requirement-to-test traceability

See [`docs/tasks/22_verification_plan.md`](docs/tasks/22_verification_plan.md) for the full verification checklist.

## Release Builds

Release artifacts are signed with the project release keystore (alias `upload`). The keystore is kept
**outside this repository** on the release machine — never copy it back in — and `android/key.properties`,
which is git-ignored, supplies its absolute path and password. Fill in the password there before the first
release build; use forward slashes in `storeFile`, because a `.properties` file treats `\` as an escape
character.

```bash
flutter build appbundle --release   # Google Play upload
flutter build apk --release         # installable APK
```

A release build fails immediately with an explanatory error while `android/key.properties` is missing
or blank, so a debug-signed artifact can never be published by accident; debug and profile builds are
unaffected. Keep an offline backup of the keystore and its password in separate places, and record the
certificate fingerprints (`keytool -list -v -keystore <keystore>`) because Google Play and any future
API-key restriction need them.

## Running With A Backend

The app talks to Supabase only when the build carries the connection settings, so a plain
`flutter run` starts the fully offline diary. To run against the project, copy the values into a local,
git-ignored `env.json` (`SUPABASE_URL`, `SUPABASE_ANON_KEY` — the publishable/anon key, never the
service key — and `GOOGLE_WEB_CLIENT_ID`) and pass it to the build:

```bash
flutter run --dart-define-from-file=env.json
```

The URL must name the one writable project (`lsthasywrdrhuuxnykau`); any other project, the off-limits
one included, is treated as *not configured* and the app runs offline rather than reaching the wrong
backend.

## Documentation

- [Authoritative implementation plan](docs/implementation_plan.md)
- [Full verification plan](docs/tasks/22_verification_plan.md)

## License

No license has been specified. All rights are reserved unless a license is added to the repository.
