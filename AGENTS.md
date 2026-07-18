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

## Phase completion protocol (end of EVERY phase)

1. Run `flutter analyze`; fix ALL errors and warnings you introduced. Phase is not complete until clean.
2. Append to `docs/version_history.md`: `Version: X.Y.Z - [brief summary]` (sequential bump) and update its `## Current Version` section.
3. Update `docs/currentlyWorking.md`: `### [Date Time] — Current Task: [brief description]`.

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

## Agent Skills

- Official skills under `.agents/skills/` are optional procedural guidance.
- Invoke only skills relevant to the current phase; do not preload all skills.
- Skills never override the current task, referenced plan sections, or this file.
- Do not use an online/networking skill during Part A.
- Do not use a skill to change architecture, dependencies, serialization, routing,
  or testing strategy unless the task permits it or the user approves it.