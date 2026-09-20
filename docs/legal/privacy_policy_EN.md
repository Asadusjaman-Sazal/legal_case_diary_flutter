# Privacy Policy — Legal Case Diary

**Effective date:** [TO CONFIRM — set on release]
**Applies to:** the Legal Case Diary Android application ("the app", "we", "us")
**Document version:** 1.0 (draft)

> **Status:** draft for legal review. Items marked **[TO CONFIRM]** are business decisions that
> must be settled before this is published. This document reflects the app as built: the released
> version works **entirely offline** and transmits nothing. The online-sync sections describe the
> version that follows, and they take effect when that version is released.

---

## 1. Summary

- **In the offline version, we collect nothing about you.** Your diary — your cases, your clients'
  details, your notes and your references — is stored only on your device, in encrypted form. It is
  never sent to us and we cannot see it.
- **We do not sell, rent or share your data.** The app contains no advertising, no analytics and no
  third-party tracking.
- **You decide what leaves your phone.** A backup file, a printed PDF or a message to a client
  leaves the device only when you choose to save, share or send it.
- **When the online version launches**, storing your diary in the cloud becomes possible, and this
  policy will then also cover the account and cloud data described in section 6.

---

## 2. Who is responsible for your data

The app is developed and published by **Asadusjaman Sazal**, an individual developer based in
Narayanganj, Bangladesh. For the purposes of this policy, we are the controller of any data we
ourselves hold. **[TO CONFIRM: legal entity — sole developer or registered business — and the full
postal address to publish.]**

- **Email:** adv.asadusjaman@gmail.com
- **WhatsApp:** +880 1835 252721

**Important:** for the case and client information you enter, **you are the controller and we are
not**. That information concerns your clients, opposing parties, witnesses and others. In the
offline version we never hold it. If you enable online sync, we hold it only on your instruction, as
your processor, under section 6.

---

## 3. What the app does with your data, by version

| | Offline version (released) | Online version (when released) |
|---|---|---|
| Where your diary is stored | Only on your device | On your device **and**, if you subscribe and enable sync, on our cloud database |
| Is anything sent to us? | **No** | Only the synced records needed to keep your devices in step |
| Account required? | **No** | Yes, to sync |
| Encryption at rest | Full-database encryption on the device | Full-database encryption on the device; encryption in transit and at rest in the cloud |

You may use the offline version indefinitely without ever creating an account. Nothing in this
policy obliges you to enable sync.

---

## 4. What is stored on your device

The app stores the following locally. None of it leaves your device unless you take an action in
section 5.

**Case and diary records** — case type, number and year; court, court category, district and
division; parties (petitioner, respondent, and on whose behalf you appear); your client's name and
phone number where you enter it; hearing dates; the steps, results and history you record; remarks;
and whether a case is disposed.

**Notes and references** — your notes (title and body) and your case-reference library (reference or
citation, statute, section, title, description and comments). A case reference is a personal
citation library entry; it is not transmitted anywhere.

**Your profile details**, used for your own display and for printed documents — full name, bar
association, membership number, office address and mobile number, and a profile picture if you
choose one.

**App settings and state** — language, view preferences, the default landing page, notification
preferences (whether alerts are on, how many days before a hearing, and the time of day), backup
status (the time and location of your last backup and your chosen interval), and the local flag that
records that the monthly backup reminder has been shown.

**Third parties' personal data.** Your entries may include personal data about other people —
clients, opposing parties, witnesses, court staff. You are responsible for having a lawful basis to
hold that information and for the professional duties of confidentiality that apply to it.

**Permissions the app requests, and why:**

| Permission | Why it is needed |
|---|---|
| Notifications / exact alarms (`POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`) | To deliver hearing reminders at the time you choose. If you decline, the app falls back to an inexact alarm or no reminder, and everything else keeps working. |
| Run at startup (`RECEIVE_BOOT_COMPLETED`), wake lock (`WAKE_LOCK`) | To re-arm your hearing reminders after the phone restarts and to let a reminder fire while the device is idle. |

The app does **not** request location, contacts, camera, microphone, or broad file access. When you
choose a file to save a backup to or open one from, you do so through the operating system's own
picker, and the app receives only the file you selected.

---

## 5. When your data leaves the device — always because you asked

- **Backups.** A backup file is written where you choose, through the system file picker. The file is
  encrypted with AES-256-GCM using a key derived from *your* passphrase. **We never receive your
  passphrase and cannot recover it or decrypt your backup.** If you send that file to Google Drive,
  email or anywhere else, that copy is then governed by that service's own terms and privacy policy.
- **Sharing and printing.** When you share a backup, print a case list or case details, or send a
  prepared message to a client over SMS or WhatsApp, that content goes to the app or service you
  chose. We are not involved and receive no copy.
- **Support.** If you contact us, we see whatever you choose to send — for example your description
  of a problem, your phone model, your app version, or a screenshot. Please do not send us the
  contents of your diary or your passphrase unless you intend to share them.

---

## 6. The online version — accounts, cloud sync and payments

This section applies **only** once the online version is released and you choose to create an
account or subscribe. **The released offline version does not collect any of this.**

**Account data.** Full name, email address, password, and your role (individual, firm owner,
associate or viewer). Authentication is handled by our hosting provider, Supabase; **passwords are
stored only as salted hashes and are never visible to us**. If you join a firm, your name, role and
permission flags (add, edit, delete) are shared with the other members of that firm, because the app
shows who last edited a record.

**Firm data.** Firm or chamber name; the membership and permission records of its associates;
single-use invite codes, which are stored **only as SHA-256 hashes** — the plaintext code is shown
once and never stored or logged; a record of failed invite attempts, used to rate-limit password-
like guessing.

**Synced diary records.** If you subscribe and enable sync, the records described in section 4
(cases, history, notes, references, and any courts, case types, steps or on-behalf entries you
customised) are copied to our cloud database so your devices stay in step. Access is restricted by
row-level security so that, by default, only you and — if you are in a firm — the members of your
firm can reach them. Firm deletion requests and conflict records are also kept so that permissions
and disputed edits are auditable.

**Payment data.** Plans are paid by mobile financial service (bKash, Nagad or Rocket) and verified
manually by us. To verify a payment we collect the plan chosen, the exact amount, the provider, the
**sender's mobile number**, the **transaction ID**, and any review notes; we also keep an audit
record of who approved it and what expiry it produced. We do **not** collect or store card or bank
account details, and we do not process the payment itself — the transfer happens entirely between
you and the provider.

**Diagnostics.** The app currently contains no analytics, crash-reporting or advertising software,
and we do not track your use of it. If we ever add diagnostic reporting, it will be limited to
technical metadata by default, will exclude your case content and any key or passphrase, and will
require your explicit consent before any payload is included.

**Third parties who process data for us:**

| Provider | Purpose | Notes |
|---|---|---|
| Supabase | Cloud database, authentication and file infrastructure | Our processor; the data is held in Supabase's infrastructure **[TO CONFIRM: hosting region]** |
| Google Play | App distribution and, where applicable, purchase processing | Governed by Google's own terms |
| Google Drive, email, messaging apps | Receiving a backup or shared content | Only when you choose them; not our processors |

**International transfers.** Our hosting provider may store data outside Bangladesh. Where data is
transferred, we rely on the provider's contractual safeguards. **[TO CONFIRM: region and the
transfer basis to cite.]**

---

## 7. How long we keep data

| Data | Retained |
|---|---|
| Everything stored on your device | Until you delete it in the app, or uninstall the app or clear its data |
| Backup files you created | Under your control, wherever you saved them. We hold none and cannot delete yours for you. |
| Account and synced records (online) | While your account exists. On deletion of your account, removed from live systems within **[TO CONFIRM: e.g. 30 days]**, and from backups within **[TO CONFIRM: e.g. 90 days]**. |
| Payment submissions and approval records | For accounting, dispute and audit purposes for **[TO CONFIRM: e.g. 6 years]** after the payment, then deleted. |
| Failed invite attempts (online) | Automatically cleaned up within one day. |

---

## 8. Your choices and rights

- **Access and portability.** Everything the app holds is yours and is visible in the app. The
  in-app **Backup to Local Storage** function produces a complete, portable, encrypted copy of your
  diary at any time — this is your export.
- **Correction.** You can edit or delete any record in the app.
- **Deletion.**
  - *Device data:* delete records in the app, or uninstall the app / clear its data.
  - *Account and cloud data (online version):* email us at adv.asadusjaman@gmail.com from your
    registered address and we will delete your account and its cloud records. **Note that the
    in-app "Delete Account" control in Settings is not yet active** — until the online version
    ships, deletion is handled by contacting us.
  - *Backups you hold:* only you can delete these. Because they are encrypted with your passphrase,
    we cannot open or erase them.
- **Withdrawing consent.** You can stop sync at any time and continue using the app offline. You can
  turn notifications off in Settings.
- **Complaints.** Contact us first at the address in section 2. You may also have the right to
  complain to the relevant data-protection authority in your jurisdiction.

---

## 9. How we protect data

- **On your device, your diary is not stored in plaintext.** The local database is fully encrypted;
  the key is generated on your device and held in Android Keystore-backed secure storage, never in
  the app's plain preferences, never in source code, and never in logs.
- **Backups are encrypted** with AES-256-GCM, with the key derived from your passphrase using
  PBKDF2-HMAC-SHA256. The file carries a versioned header, a nonce, an authentication tag and a
  checksum, so a damaged or altered file is rejected rather than imported.
- **When syncing (online version),** data is encrypted in transit, access is restricted by row-level
  security so that one user cannot read another's records, premium entitlement is checked on the
  server rather than trusted from the device, and only narrowly-scoped server functions may change
  subscription status or approve a payment.
- **On logout,** the device's local database is wiped to prevent one account's data appearing in
  another's session. Before that wipe, the app offers to export your data so nothing unsynced is
  lost silently.
- **Only passwords we cannot read.** We never ask for, store or transmit your backup passphrase.

No system is perfectly secure. If you become aware of a security issue, please tell us at the
address in section 2 so we can act on it.

---

## 10. Children

The app is a professional tool for legal practitioners and their staff. It is not intended for
anyone under 18, and we do not knowingly hold data about children except where it appears in a
lawyer's own case records.

---

## 11. Changes to this policy

If we change this policy we will update the version and effective date above and show the current
version in the app's About screen. Where a change materially affects how your data is handled — for
example, when online sync begins — we will tell you in the app before the change takes effect.

---

## 12. Contact

**Asadusjaman Sazal** — adv.asadusjaman@gmail.com — WhatsApp +880 1835 252721
**[TO CONFIRM: postal address for formal notices.]**

---

*This document is a draft prepared alongside the app's implementation and is not a substitute for
legal advice. It should be reviewed by a qualified lawyer, particularly on the governing-law and
international-transfer points, before publication.*
