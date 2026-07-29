### 2026-07-29 — Current Task: Task 04 (Pre-Seeded Data & Versioned Seed Migrations) — COMPLETE

All phases complete:
- Phase 1: `pre_seeded_data.dart` with typed structures, stable IDs, all domain data (8 categories, 8 divisions, 64+ districts, supreme courts, lower courts for Dhaka & Narayanganj, steps, case types, on-behalfs, disposed steps)
- Phase 2: `seed_migration_runner.dart` with versioned, idempotent seed migrations using SQLite UPSERT to preserve user-modified rows, checksum ledger
- Phase 3: `seed_data_test.dart` — 24 tests covering all data structures, uniqueness, labels, mandatory on-behalf mapping
- Phase 4: `seed_migration_runner_test.dart` — in-memory Drift integration tests verifying seeding, idempotency, and user-modified row preservation
- L10n: ARB files updated with 8 new on-behalf roles, `app_translations.dart` seed label resolver
- `database_provider.dart` triggers seed migrations on startup

`flutter analyze` clean, all 63 tests pass.

**Next:** Task 05 — Repositories, DAOs, and State Management.
