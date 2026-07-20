# OpenCode Per-Task Prompt (Legal Case Diary)

> Project-wide binding rules live in `AGENTS.md` (repo root). OpenCode loads it automatically every session, so this prompt no longer repeats those rules — it only adds per-task instructions. Keep both files in sync if rules change.

Copy the block below, replace `{NN}` with the task number (e.g. `07`), and paste it into OpenCode at the start of each task session.

---

## PROMPT — paste from here

You are implementing Task {NN} of the Legal Case Diary Flutter app. All rules in `AGENTS.md` are binding — follow them without me restating them. Work in two roles: PLAN first (Architect model), then BUILD (Builder model).

### Context loading — read ONLY these, in this order

1. `docs/currentlyWorking.md` — resume point.
2. `docs/tasks/{NN}_*.md` — the full task file, including its Revision 2.4 Alignment Addendum (Addendum overrides contradictory earlier wording in the same file).
3. From `docs/implementation_plan.md`, ONLY the sections the task file explicitly cites. Do NOT read the whole plan.
4. Mockup HTML files under `legal_case_diary_flutter\mockup_html_screens\` ONLY for the screens this task builds. Do Not load them if they are not required for this task.

Do not re-read files already summarized in your context. Do not read other task files unless this task file cites them. You do not need to read `docs/tasks/00_INDEX.md` — its Universal Working Rules are already captured in `AGENTS.md`.

### PLAN phase (Architect)

- Preserve the task file’s existing phases and order. For each phase, briefly
  identify the files to create/modify, key implementation decisions, applicable
  plan sections, and validation steps. Do not add, remove, merge, split, or
  reorder phases unless a conflict makes this necessary; flag such a conflict
  and wait for approval. Bullet points only, no code.
- State the table class (per AGENTS.md rule 4) for every table you touch.
- If anything is unclear or conflicting: STOP and ask me (batched list). If the task file and implementation plan disagree, the plan wins — flag it.
- Wait for my approval before building.

### BUILD phase (Builder)

- Implement one phase at a time, exactly as planned.
- Follow the AGENTS.md phase completion protocol at the end of EVERY phase (`flutter analyze` clean, `version_history.md`, `currentlyWorking.md`).
- After the final phase, run the task file's acceptance tests/checklist (including Addendum items) and report pass/fail per item.
- Use only relevant official skills from `.agents/skills/`. State which skills you
will invoke before implementation. Skills are subordinate to the task, plan,
and `AGENTS.md`; do not invoke irrelevant or Part-A networking skills.

Begin with the PLAN phase for Task {NN} now.

## PROMPT — end
