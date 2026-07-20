# Legal Case Diary — Agentic Development Guide

## 1. Recommended environment

Use **OpenCode** as the primary coding environment. Its Plan/Build roles fit this project’s task-driven workflow better than Hermes Agent. Use Hermes only as an optional research or autonomous parallel-investigation tool.

- **Architect model:** strongest reasoning/context model; read-only permissions.
- **Builder model:** strongest Dart/Flutter coding and tool-use model; write/test permissions.
- **Explore model (optional):** fast, inexpensive model for file/symbol discovery only.

The repository—not chat history—is authoritative.

## 2. Sources and precedence

1. Current task’s Revision 2.3 Alignment Addendum
2. Current task file: `docs/tasks/{NN}_*.md`
3. Cited sections of `docs/implementation_plan.md`
4. Root `AGENTS.md`
5. Installed agent skills
6. General model knowledge

Task order and global rules are indexed in `docs/tasks/00_INDEX.md`. Resolve any revision/header mismatch in the implementation plan before development. Never guess: stop and batch clarification questions.

## 3. Standard task workflow

Use `docs/opencode_task_prompt.md`, replacing `{NN}`. Handle exactly one task per branch/session.

1. Create branch `task/NN-short-name` from clean `main`.
2. Start a fresh OpenCode session; `AGENTS.md` loads automatically.
3. **PLAN (Architect):** read only `currentlyWorking.md`, the task file, explicitly cited plan sections, relevant code, and referenced mockups. Produce phases, affected files, decisions, table classes, tests, exclusions, and applicable skills. No edits.
4. Review questions and approve the plan.
5. **BUILD (Builder):** implement one approved phase at a time. Do not redesign, expand scope, or implement future tasks.
6. End every phase with formatting, analysis, targeted tests, diff review, and required documentation updates.
7. After the final phase, execute every task/Addendum acceptance item and report pass/fail.
8. Run the full test suite and Android debug build; inspect changed UI manually.
9. Review `git diff`, commit verified work, merge, then begin the next task in a fresh session.

## 4. Required quality gates

At minimum, as applicable:

```powershell
dart format --set-exit-if-changed .
flutter analyze
flutter test
dart run build_runner build --delete-conflicting-outputs
flutter build apk --debug
```

- Run targeted tests after each phase and all tests at task completion.
- `flutter analyze` must be clean; compilation alone does not prove behavior.
- Test fresh-install and upgrade migrations for database changes.
- For UI, verify Bengali/English, text scaling, overflow, keyboard behavior, accessibility, and empty/loading/populated/error states.
- For sync, cover offline writes, queue compaction, retries, duplicates, conflicts, cursors, tombstones, permission loss, and multi-device convergence.
- Update `docs/version_history.md` and `docs/currentlyWorking.md` after every phase as specified by `AGENTS.md`.

## 5. Project invariants

- Architecture: MVVM + Repository, Riverpod, Drift + SQLCipher, GoRouter.
- Tasks 01–15 are strictly offline: no Supabase dependency, network code, or server auth calls.
- Offline writes still maintain sync metadata and `sync_queue`.
- Classify every table: push/pull domain, pull-only cache, per-user preference, local operational, or server-managed.
- DB names use `snake_case`; Dart/JSON uses `camelCase`.
- Match cited HTML mockups exactly; mobile-first only.
- Never use `BackdropFilter`.
- Preserve valid comments and add concise intent comments where required.
- Touch only files/sections needed by the current task.

## 6. Skills

Install official skills project-locally so they are versioned and loaded on demand:

```powershell
npx skills add dart-lang/skills --skill '*' --agent universal --yes
npx skills add flutter/agent-plugins --skill '*' --agent universal --yes
npx skills update
```

They should appear under `.agents/skills/`. Review their diff before committing. Prefer a curated subset if discovery noise becomes excessive.

High-value skills:

- Dart: static analysis, unit tests, coverage, mocks, runtime fixes, package conflicts.
- Flutter: widget/integration tests, responsive layout, layout fixes, routing, localization, widget previews.

Skills are procedural guidance only. Invoke only those relevant to the current phase. They cannot override project sources, change architecture/dependencies without approval, or introduce networking during Part A. Treat architecture, HTTP, and serialization skills cautiously when the plan already dictates an approach.

Useful custom skills:

- `flutter-quality-gate`
- `drift-migration-review`
- `flutter-ui-verification`
- `supabase-security-review` (Part B only)
- `task-closeout`

## 7. MCPs and tools

Keep the toolset small to reduce context, ambiguity, and risk.

### Recommended

- **Official Dart/Flutter MCP:** structured analyzer, test, runtime, and Flutter operations; pin a compatible stable SDK.
- **Context7:** current documentation for the exact installed package versions.
- **Terminal:** authoritative formatting, analysis, tests, builds, and Git operations.

### Part B only

- **Official Supabase MCP:** development project only, scoped by `project_ref`, read-only by default. Require approval for migrations, RLS, functions, or destructive SQL. Never expose service-role credentials to Flutter or connect an unrestricted agent to production.

Example safe starting endpoint:

```text
https://mcp.supabase.com/mcp?project_ref=<development-project-ref>&read_only=true
```

### Optional

- GitHub MCP only for issue/PR workflows; local Git/CLI is sufficient otherwise.
- Sentry only when beta/production monitoring begins.

Avoid redundant filesystem, shell, Git, browser, and generic-search MCPs when OpenCode already supplies equivalent tools.

## 8. Permissions and approval gates

**Architect:** read/search/docs/diffs and non-mutating inspection only.

**Builder:** project writes, Flutter/Dart/Gradle commands, and approved dependencies. No production access, force push, secret exposure, or unapproved destructive actions.

Require explicit approval before changing architecture, dependencies, database schemas, RLS/functions, native configuration, backup formats, routing/serialization/testing strategy, deleting files, remote mutations, commits, pushes, or merges.

## 9. Git and environment discipline

- Use Git from Task 01; protect `main`.
- Prefer one verified commit per phase or small task.
- Example: `feat(cases): implement add and edit workflow`.
- Never commit failing code, secrets, signing keys, local databases, build output, or machine-specific configuration.
- Review lockfile/generated-file changes.
- Use FVM and pin Flutter/Dart, Java, Gradle, and Android tooling versions to prevent Windows environment drift.

## 10. Token and context economy

- Fresh session per task; compact only between phases.
- Read only task-relevant files and cited plan sections.
- Reference paths/symbols instead of quoting files.
- Do not restate requirements or standard Flutter concepts.
- Keep phase reports to concise `changed / pending / blockers` bullets.
- Load MCPs and skills only when needed.
- Summarize successful logs; retain details only for failures.
- Use `git diff` instead of full-file recaps.
- Record durable decisions in repository docs, never only in chat.

## 11. Minimum setup

**Part A:** OpenCode Plan/Build agents, `AGENTS.md`, per-task prompt, Git, FVM, Dart/Flutter MCP, Context7, official Dart/Flutter skills, and quality/database/UI review skills.

**Part B:** add a separate development Supabase project, project-scoped Supabase MCP, and Supabase security review.

The core control loop is: **Architect plan → human approval → phased Builder implementation → automated verification → diff review → commit.**
