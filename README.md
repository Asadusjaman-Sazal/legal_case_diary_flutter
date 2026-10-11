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

### Tagged Releases (GitHub Actions)

Pushing a tag named `v` + the current version runs [`.github/workflows/release.yml`](.github/workflows/release.yml),
which builds the **arm64** release APK and publishes it as a GitHub Release:

```bash
git tag v0.0.476 && git push origin v0.0.476
```

The release is titled **Legal Case Diary v0.0.476** and its notes are the `## Current Version` line of
[`docs/version_history.md`](docs/version_history.md). A tag that disagrees with the `pubspec.yaml` version
fails the job rather than publishing a build whose version and notes disagree, and a missing secret fails
before Gradle runs.

The workflow recreates the keystore config and `env.json` from repository secrets (Settings → Secrets and
variables → Actions), so neither file is ever committed:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | the release keystore, base64-encoded: `base64 -w0 <keystore>` |
| `ANDROID_KEYSTORE_PASSWORD` | its `storePassword` |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | its `keyPassword` |
| `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_WEB_CLIENT_ID` | the `env.json` values described under *Running With A Backend* |
| `PAYMENTS_BKASH_NUMBER`, `PAYMENTS_NAGAD_NUMBER`, `PAYMENTS_ROCKET_NUMBER` | optional payment numbers |

## Running With A Backend

The app talks to Supabase only when the build carries the connection settings, so a plain
`flutter run` starts the fully offline diary. To run against the project, copy the values into a local,
git-ignored `env.json` (`SUPABASE_URL`, `SUPABASE_ANON_KEY` — the publishable/anon key, never the
service key — and `GOOGLE_WEB_CLIENT_ID`) and pass it to the build:

```bash
flutter run --dart-define-from-file=env.json
flutter build apk --release --dart-define-from-file=env.json
```

Because the values are compile-time constants, forgetting the flag is silent — the build simply starts
in its offline shape. `tool/flutter_with_env.dart` is a thin wrapper that always appends the flag, for
debug and release alike, and refuses to build when `env.json` is missing so a release cannot ship
offline by accident:

```bash
dart run tool/flutter_with_env.dart run -d <device>
dart run tool/flutter_with_env.dart build apk --release
```

The URL must name the one writable project (`lsthasywrdrhuuxnykau`); any other project, the off-limits
one included, is treated as *not configured* and the app runs offline rather than reaching the wrong
backend.

## Google Sign-In Setup and Troubleshooting

Native Google sign-in needs two Android OAuth clients in the **same Google Cloud project as the web
client** the build passes as `GOOGLE_WEB_CLIENT_ID`, one per signing certificate, all with the package
name `com.legalcasediary.app`.

| Build | Keystore | SHA-1 | SHA-256 |
| --- | --- | --- | --- |
| Debug | `~/.android/debug.keystore`, alias `androiddebugkey` | `9D:8B:8E:D1:6A:52:C0:4B:B9:67:7B:C1:A2:71:3C:81:11:FD:B2:9D` | `25:21:A6:F8:81:A9:AD:52:A3:01:29:69:60:01:40:D9:78:14:0F:7A:38:FC:9D:A0:29:02:A0:A7:03:6D:04:8B` |
| Release | the project release keystore, alias `upload` | `EB:7A:81:19:03:5C:EF:B0:D4:A3:2E:86:43:FB:09:F1:8A:25:9D:6B` | `E9:8A:92:4B:F0:98:74:06:60:10:83:28:BC:E2:DE:C5:85:61:2D:53:D9:D3:7E:4E:FA:15:1B:9E:1C:9E:03:B8` |

Re-read them at any time; the release keystore path and password live in `android/key.properties`:

```bash
keytool -list -v -keystore "$HOME/.android/debug.keystore" -alias androiddebugkey -storepass android -keypass android
keytool -list -v -keystore <release-keystore> -alias upload
```

**If sign-in fails after the account picker closes**, Android's Credential Manager reports the Google-side
configuration failure as a *cancellation*, so the sheet appears to close and nothing happens. An
instrumented run prints the tell-tale pair — a plugin line, then a `[16]` GMS code:

```text
I/PlayServicesImpl: No cancellationSignal found
I/flutter: Google sign-in failed: GoogleSignInException(code GoogleSignInExceptionCode.canceled, [16] Account reauth failed., null)
```

The app now turns that code into a visible *Google Sign-In Could Not Complete* message, so a real failure
no longer looks like a dismissal — but the cause is still server-side configuration:

- **Check the network first.** The same `[16]` appears when the request never reached Google — a Wi-Fi
  network with no uplink produces it exactly as a certificate mismatch does, and `ConnectivityMonitor`
  cannot see that case because it reports the *link*, not the internet. Google sign-in now makes a short
  request to the project before opening the sheet and reports *"No Connection. Check Your Internet And
  Try Again."* instead, so switching to mobile data is an obvious first thing to try.
- **Register the signing certificate.** Add an Android OAuth client for the SHA-1 of the build being run
  (debug, release, *and* the Google Play **App signing key certificate** from Play Console → App integrity,
  because Play re-signs uploads with its own key). A certificate mismatch is the other usual cause of `[16]`.
- **Check the package name** on each Android client: `com.legalcasediary.app`, with no typo or variant.
- **Check `GOOGLE_WEB_CLIENT_ID`** — it must be the *Web* client from that same project, and the value
  Supabase Auth is configured to trust; a Web client from another project fails the same way.
- **Publish or allowlist the consent screen.** While the OAuth consent screen is in *Testing*, every
  account that signs in must be listed under **Audience → Test users**.
- **Reproduce with the wrapper**, so the credentials are actually compiled in:
  `dart run tool/flutter_with_env.dart run -d <device>`.

## Auth E-mail Links (Confirmation and Password Reset)

The mails Supabase sends send the user back to the app through one custom scheme:

```text
com.legalcasediary.app://login-callback
```

The build passes it as `emailRedirectTo`/`redirectTo` on sign-up and password recovery, and
`android/app/src/main/AndroidManifest.xml` claims it with an `<intent-filter>`. Without it Supabase
falls back to the project's **Site URL**, which is why a link can land on a `localhost:3000` page that
is not there:

- **Authentication → URL Configuration → Redirect URLs** must contain the scheme above, exactly. The
  allow-list is what makes Supabase honour the app's redirect at all.
- **Authentication → URL Configuration → Site URL** must be a real page — it is the fallback for any
  link that carries no redirect of its own.
- The **Reset Password e-mail template** must keep `{{ .Token }}`, because the app's own reset flow uses
  the code the user types in; the link is a second, optional way in.

For the deep-link test command and the full walkthrough, see
[Google Sign-In Setup — Every Client Type, Step by Step](docs/google_oauth_setup.md). That runbook also
covers every Google client type (Web, Android debug/release/Play app-signing, iOS).

## Documentation

- [Authoritative implementation plan](docs/implementation_plan.md)
- [Full verification plan](docs/tasks/22_verification_plan.md)

## License

No license has been specified. All rights are reserved unless a license is added to the repository.
