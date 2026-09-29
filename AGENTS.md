# AGENTS.md — Legal Case Diary (Flutter)

Binding project-wide rules for all agents. Task-specific requirements live in `docs/tasks/{NN}_*.md` — this file never overrides them.

## Project

- Flutter app for lawyers: offline-first case diary, later synced to Supabase.
- Architecture: MVVM + Repository, Riverpod state, Drift + SQLCipher local DB, GoRouter navigation.
- Source of truth: `docs/implementation_plan.md` (Revision 2.4). If a task file and the plan disagree, the plan wins — flag the discrepancy, don't guess.
- Task order and Universal Working Rules: `docs/tasks/00_INDEX.md`. Each task's Revision 2.3 Alignment Addendum overrides contradictory earlier wording in that same file.

## Hard rules (never violate)

1. **Never guess.** If a requirement, UI detail, data rule, or edge case is unclear or conflicting, stop and ask the user. Batch questions into one list.
2. **Scope:** only touch files/sections the current task instructs you to. Never implement future tasks early.
3. **Part A (Tasks 01–15) is strictly offline.** No `supabase_flutter`, no network code, no auth-server calls. Every write path must still maintain sync columns (`version`, `updated_at`, `is_deleted`, `synced_at`, `last_modified_by`) and populate `sync_queue`.
4. **Table classes are mandatory:** classify every table touched as push/pull domain, pull-only cache, per-user preference, local operational, or server-managed. Never apply generic sync behavior across classes.
5. **Naming:** DB columns `snake_case`, Dart/JSON `camelCase`, Drift auto-mapping between them.
6. **Comments:** short intent comments on every file and major section. Never delete existing comments unless they conflict with new logic.
7. **No `BackdropFilter` anywhere** — use the performance-safe alternatives from the plan.
8. **Mobile-first only.** No tablet/desktop optimization yet.
9. **Mockups are mandatory:** screen bodies must exactly match the referenced files under `legal_case_diary_flutter\mockup_html_screens\`.
10. **Rev 2.4 scope contract:** editable court categories/courts/steps/case types/on-behalfs are domain-synced and firm-shared in firm mode; language, view, navigation, notification, and backup-nudge settings are always per-user.
11. **Casing:** user-facing English text is **Title Case** — the first letter of every word capital, the rest lowercase — written that way in the ARB itself. Section headings follow the same rule, so there is no render-time `toUpperCase()`/ALL-CAPS styling. Proper nouns, acronyms, product names and the names of courts, offices and roles keep their capitals (WhatsApp, FAQs, PDF, Google Drive, Legal Case Diary, Chief Judicial Magistrate). Bengali is unaffected: it has no letter case.
12. **Supabase project scope — one project is writable, another is untouchable.** The **only** project any agent may read or write is `lsthasywrdrhuuxnykau` ("Legal Case Diary", org `xrjmednwyszriubyjzgb`). **`ykbwzodadijtiizobehk` ("Swanirvor-23") is live and must never be touched in any way** — no read, no write, no migration, no SQL, no branch, no edge function, no log query, no settings change. Check the `project_id`/`project_ref` against this allow-list *before* every Supabase connector call and stop if it is missing, different or ambiguous; never reuse an id from earlier output, never iterate `list_projects` blindly, and never edit `~/.freebuff/mcp.json` to widen reach.
13. **Every Supabase SQL is written into `supabase/AllSupabaseSql.md`.** All server SQL lives as a file under `supabase/migrations/` — that is the only write path — and `supabase/AllSupabaseSql.md` is the single ordered record of **every** statement this project has ever run against Supabase, sectioned by creation order and the app version recorded at that phase, each section labelled with a comment saying what it does. The file is **generated**: run `dart run tool/generate_all_supabase_sql.dart` after adding or editing any migration, and never hand-edit it. `dart run tool/generate_all_supabase_sql.dart --check` and `test/supabase/all_supabase_sql_test.dart` fail on drift.

## Phase completion protocol (end of EVERY phase)

1. Run `flutter analyze`; fix ALL errors and warnings you introduced. Phase is not complete until clean.
2. **Read Files:** Read `docs/version_history.md`, `pubspec.yaml`, and `docs/currentlyWorking.md`.
3. **Record the version with the script, never by hand:** `python tool/record_version.py --summary "One short, precise sentence."` reads the version under `## Current Version`, increments the **patch** component (`X.Y.Z` → `X.Y.Z+1`), writes the new entry as the **only** entry there (it replaces the previous one — a new entry is never placed above it), appends that same line directly under the last line of `## Version History Log` (never after a blank line), and updates `pubspec.yaml` and `lib/core/constants/app_version.dart`. Do not edit those four places by hand.
4. **Keep the summary short and precise:** one sentence, at most 300 characters, saying what changed and why. The long account (request, decisions, tests, resume point) belongs in `docs/currentlyWorking.md`.
5. **The rules are enforced, not remembered.** `test/core/version_history_test.dart` fails the suite on a duplicated `## Current Version` entry, an entry missing from the end of the history, a blank or stray line between entries, an over-long entry, or a version that does not increase; `python tool/record_version.py --check` reports the same without writing. Fix the log with the script, never by hand.
6. **`pubspec.yaml` and `lib/core/constants/app_version.dart`:** the script above writes both to the new version, so there is nothing to do by hand; if you ever write them by hand, keep the exact numeric string (no prefix or summary) and re-run `python tool/record_version.py --check`.
7. **Update `docs/currentlyWorking.md`:** Document completed phase and next resume point.
8. **File Layout Reference (`docs/version_history.md`)**
```markdown
## Current Version:
Version: 0.0.41 - Task 07 Phase 1 complete: ...

## Version History Log:
...
Version: 0.0.40 - Task 06 Phase 4 complete: ...
Version: 0.0.41 - Task 07 Phase 1 complete: ...
```

## Session protocol

- Start every session by reading `docs/currentlyWorking.md` to find the resume point.
- Read ONLY: the current task file, the plan sections it explicitly cites, and the mockups for the screens it builds. Do not read the whole plan or unrelated task files.
- PLAN before BUILD: propose a terse phase-by-phase plan and wait for user approval before writing code.
- After the final phase, run the task file's acceptance tests/checklist (including Addendum items) and report pass/fail per item.

## Output discipline (token economy)

- Do not restate requirements, summarize files you read, or explain standard Flutter/Dart concepts.
- Reports are bullet lists (changed / pending / blockers), max ~10 lines between phases.
- Code appears only in file edits, never duplicated in chat.

## Commands

- Analyze: `flutter analyze` (must be clean per phase)
- Environment: Windows; use Windows-style paths where the docs do.

## Default Coding Policy — Ponytail

Ponytail is the project’s default coding policy for every coding task. Apply its full mode unless the user explicitly requests `lite`, `ultra`, or normal mode.

- Understand the task and trace the affected flow before simplifying.
- Stop at the first solution rung that works: YAGNI, existing project code, standard library, native Flutter/Dart capability, installed dependency, one line, then the minimum new code.
- Prefer deletion, reuse, boring solutions, and the fewest changed files. Do not add speculative abstractions, boilerplate, configuration, or dependencies.
- Never simplify away correctness, validation, error handling, security, accessibility, data-loss protection, required tests, or explicit user requirements.
- For non-trivial simplifications, leave one runnable check behind. Mark deliberate shortcuts with a `ponytail:` comment that names the ceiling and upgrade path.
- The project’s existing rules, task scope, cited plan sections, mockups, and acceptance criteria take precedence over Ponytail’s general guidance.

## Agent Skills

- Official skills under `.agents/skills/` are optional procedural guidance.
- Invoke only skills relevant to the current phase; do not preload all skills.
- Skills never override the current task, referenced plan sections, or this file.
- Do not use an online/networking skill during Part A.
- Do not use a skill to change architecture, dependencies, serialization, routing,
  or testing strategy unless the task permits it or the user approves it.
- The project-local Ponytail skills are installed under `.agents/skills/` for focused use:
  `ponytail`, `ponytail-review`, `ponytail-audit`, `ponytail-debt`,
  `ponytail-gain`, and `ponytail-help`.
