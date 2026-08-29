# Archived migrations — do not run these

These ran (fully or partly) against production long ago. They live here, out of
`migrations/`, so `migrate.sh` never picks them up again.

They are kept for history only. `schema.sql` is a dump of the current production
schema, so a fresh database already reflects whatever these did — there is
nothing to replay.

## Why they were pulled out

They only ever **drop** things, and a drop is the one operation that cannot be
made safe by re-running it. Two are actively dangerous today:

- **`2026_06_14_drop_unused_feature_tables.sql`** drops `candidates` and
  `job_openings`. `models/AuditLogModel.php` still does
  `SELECT id, name FROM candidates ...` when it resolves audit-log labels.
  Running this file would leave that query hitting a missing table. Both tables
  are still present in production precisely because this migration was never
  fully applied there.

- **`2026_06_14_remove_kiosk_system.sql`** drops the `branches.station_*`
  columns. Production still has them; nothing reads them, but the file was only
  partly applied, so re-running it half-succeeds and reports failure.

The rest (`drop_expenses`, `drop_unused_columns`, `drop_subscriptions_plans`,
`drop_frontend_unused_columns`, `drop_shift_color`) are harmless but equally
pointless to replay — several of the columns they remove were deliberately
re-added later by the face-selfie and leave-carryover migrations.

## If you actually want the leftovers gone

Write a **new** dated migration that drops only what you have just confirmed is
unreferenced, and grep the PHP first:

    grep -rn "table_name" --include="*.php" app core models
