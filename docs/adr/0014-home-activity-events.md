# ADR-0014

Home activity events

## Status

Accepted

## Date

2026-08-26

---

## Context

Stock changes already have an append-only `inventory_transactions` ledger (ADR-0008). Household actions did not: create/join home, invite/remove members, add/remove rooms and items, and schedule create/complete. Planning still lists a later permission-audit `audit_logs` subsystem (Phase J). Users asked for a readable activity trail now.

## Decision

**Postgres `activity_events` is an append-only, home-scoped activity trail.** Members can SELECT. Clients cannot INSERT/UPDATE/DELETE. Writers are `SECURITY DEFINER` triggers plus `log_home_activity`.

Typical `action` values: `CREATE_HOME`, `ARCHIVE_HOME`, `UPDATE_HOME`, `JOIN_HOME`, `REMOVE_MEMBER`, `INVITE_MEMBER`, `CREATE_ROOM`, `UPDATE_ROOM`, `ARCHIVE_ROOM`, `DELETE_ROOM`, `CREATE_NODE`, `UPDATE_NODE`, `MOVE_NODE`, `DISPOSE_NODE`, `ARCHIVE_NODE`, `DELETE_NODE`, `CREATE_SCHEDULE`, `COMPLETE_SCHEDULE`, `DELETE_SCHEDULE`.

Each row stores `actor_user_id`, a human `summary` (already includes the actor label), optional `entity_type` / `entity_id`, and `metadata` jsonb.

This is **not** the Phase J permission-audit log (who was granted what, denied UUID probes). Stock Use/Restock/Dispose stay on `inventory_transactions` and are not duplicated here.

## Rationale

- One list members can read without forging rows from the client.
- Triggers keep create/join/add/remove in the database even if a client forgets to log.
- Summaries are display-ready so the Flutter list does not need to reconstruct sentences.

## Alternatives Considered

1. **Global `audit_logs` with permission events** — Phase J; still deferred.
2. **Client-inserted activity rows** — rejected: easy to forge or omit; RLS would still need a definer path for membership joins.
3. **Reuse `inventory_transactions` for everything** — rejected: that table is a stock ledger, not membership/rooms/schedules.

## Consequences

### Advantages

- Household history for create home, join, rooms, items, and schedules.
- Completing a schedule writes `COMPLETE_SCHEDULE`.

### Disadvantages

- High-churn stock Use is not in this list (by design).
- Trigger summaries are English-only.
- Not a security audit of authorization decisions.

## Security Impact

SELECT: `can_view_home`. No client write policies. `log_home_activity` is revoked from `anon` / `authenticated`. Cross-home UUID guessing is denied like other home tables.

## Database Impact

Migration: `20260826000200_schedule_complete_and_activity.sql`

## UI Impact

- `/homes/:homeId/activity`
- Home overview tile and desktop sidebar **Activity**

## References

- [`supabase/migrations/20260826000200_schedule_complete_and_activity.sql`](../../supabase/migrations/20260826000200_schedule_complete_and_activity.sql)
- [`mobile/lib/features/activity/`](../../mobile/lib/features/activity/)
- Related: [ADR-0008](0008-inventory-transactions.md), [ADR-0013](0013-reminders-and-local-notifications.md), [ADR-0003](0003-home-membership-rls.md)
