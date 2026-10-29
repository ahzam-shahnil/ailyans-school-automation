# tool/restore_rehearsal.dart

Live end-to-end verification of BackupService + DatabaseService against the
real `~/Documents/Ailyans/school_database.db`.

## What it does

Runs 11 steps (0-10) against the production database file:

| Step | Action                                              | Fail code |
|------|-----------------------------------------------------|-----------|
| 0    | sqfliteFfiInit + open live DB                       | 1         |
| 1    | Baseline row counts (Stu_Reg, VoucharMas, Teachers, session_yr) | 2 |
| 2    | Export snapshot via VACUUM INTO                     | 3         |
| 3    | Validate candidate (validateCandidate)              | 4         |
| 4    | **DESTRUCTIVE** restore (restoreFrom)               | 5         |
| 5    | Post-restore counts must match baseline             | 6         |
| 6    | PRAGMA quick_check on restored DB                   | 7         |
| 7    | Admin user check (UserLvl = 1)                      | 8         |
| 8    | WAL/SHM hygiene (files must be absent)              | 9         |
| 9    | Safety backup existence (pre_restore_*.db must exist) | 10      |
| 10   | Write rehearsal_log_<stamp>.txt                     | --        |

## Exit codes

| Code | Meaning                                |
|------|----------------------------------------|
| 0    | All steps passed                       |
| 1    | Setup / IO failure                     |
| 2    | Baseline count mismatch                |
| 3    | Export failed                          |
| 4    | Validation failed                      |
| 5    | Restore threw exception                |
| 6    | Post-restore count mismatch            |
| 7    | quick_check failed                     |
| 8    | No admin user found                    |
| 9    | WAL/SHM hygiene failure                |
| 10   | Safety backup missing                  |

## WARNING

**Step 4 is DESTRUCTIVE.** It closes and replaces the live database file.
The script creates a safety backup before restoring, but you are operating on
the real production database. Do NOT run on a machine where data loss is
unacceptable unless you have a manual backup in hand.

## Usage

From inside `rebuild/app/`:

```
dart run tool/restore_rehearsal.dart
```

## Baseline constants

Update `_baseline` inside the script when production data changes materially:

```dart
const Map<String, Object> _baseline = {
  'Stu_Reg': 670,
  'VoucharMas': 2024,
  'Teachers': 24,
  'app_config_default_session_yr': '2026-27',
};
```

## Log output

The script writes a log file to `~/Documents/Ailyans_Backups/rehearsal_log_<stamp>.txt`
(falls back to `~/Documents/Ailyans/rehearsal_log_<stamp>.txt` if the
backups directory does not exist). Console output mirrors the log exactly.
