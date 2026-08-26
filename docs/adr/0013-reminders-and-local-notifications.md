# ADR-0013

Reminders and local notifications

## Status

Accepted

## Date

2026-08-26

---

## Context

Households need repeating cleanup alarms with their own wording (“Weekly Clean-up”, “Monthly Clean-up”) and refill alerts when a container is likely to run out based on Use history. Planning still lists FCM and a full in-app notification inbox (Phase J / Phase 8). Those need Firebase and more USE history than we should assume. Users asked for reminders now, managed on both Android and the browser.

## Decision

**Postgres `reminders` is the source of truth.** Rows are home-scoped. Members can read; editors create, update, and disable. Two kinds:

| Kind | Meaning |
| --- | --- |
| `MANUAL` | User title + optional notes. Repeat: once, daily, weekly, monthly, or every N days. |
| `USAGE_REFILL` | Tied to one `inventory_node`. Client estimates daily Use (USE ledger only, not TRANSFER_REFILL) and sets `next_fire_at` to (quantity / daily rate) minus `lead_days`. |

**Delivery**

- **Android:** `flutter_local_notifications` schedules local alerts from `next_fire_at`. Daily / weekly / monthly use OS repeating components. Custom-interval and refill alerts are one-shots, then rescheduled when the app opens. POST_NOTIFICATIONS is requested when the user first saves a reminder. Exact-alarm permission is not required; schedules use inexact-allow-while-idle so a few minutes of drift is acceptable.
- **Web / all platforms:** the same Reminders screen lists, creates, edits, and turns off reminders. Browser tabs do not get reliable background alarms without FCM/service workers. Due items show in the list; if the tab is open and notification permission is granted, a browser notification may fire for currently due rows.
- **FCM / Edge Functions / inbox table:** not in this change. Push while the Android app is uninstalled, or while a browser is fully closed, is out of scope.

Refill math lives in the Flutter client (`forecastRefill`) so it is unit-tested and explainable (“2.4 CC/day from 6 Use actions over 14 days”). Confidence is withheld when there are fewer than two Use events spanning at least a day.

## Rationale

- Shared list across devices without standing up Firebase.
- Local Android notifications cover “remind me every Sunday” without a server cron.
- Usage refill reuses the existing USE ledger instead of a separate prediction table.

## Alternatives Considered

1. **FCM + Edge Function cron** — matches long-term planning; blocked on Firebase project and secrets. Deferred.
2. **Device-only reminders (no Postgres)** — rejected: web and Android would diverge; reinstall would drop alarms.
3. **Full `notifications` inbox** — Phase J; not required to manage alarms and refill reminders.

## Consequences

### Advantages

- One management UI on web and Android.
- Custom alarm wording without a fixed catalog of types.
- Refill dates stay honest when history is thin.

### Disadvantages

- Android alerts after reboot rely on the plugin’s boot receiver plus the next app open to pick up server edits.
- Web has no background alarm clock.
- Refill dates move when stock or Use history changes; they are not a server job.

## Security Impact

RLS: `can_view_home` select; `can_edit_inventory` write; insert `created_by_user_id = auth.uid()`. Cross-home UUID guessing is denied like other inventory tables. Notification payloads use the reminder title/body the household already stored.

## Database Impact

Migration: `20260826000100_reminders.sql`

## UI Impact

- `/homes/:homeId/reminders` list + create/edit form
- Home overview tile, desktop sidebar, Settings link per home
- Item detail: “Remind when low” for stocked items

## References

- [`supabase/migrations/20260826000100_reminders.sql`](../../supabase/migrations/20260826000100_reminders.sql)
- [`mobile/lib/features/reminders/`](../../mobile/lib/features/reminders/)
- Related: [ADR-0008](0008-inventory-transactions.md), [ADR-0001](0001-flutter-supabase-platform.md) (FCM still not runtime)
