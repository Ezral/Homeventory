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

**Postgres `reminders` is the source of truth.** Rows are home-scoped. Members can read; editors create, update, disable, complete, and archive. Two kinds:

| Kind | Meaning |
| --- | --- |
| `MANUAL` | User title + optional notes. Repeat: once, daily, weekly, monthly, or every N days. **Must** link to one `inventory_node` **or** one `room`. |
| `USAGE_REFILL` | Tied to one `inventory_node`. Client estimates daily Use (USE ledger only, not TRANSFER_REFILL) and sets `next_fire_at` to (quantity / daily rate) minus `lead_days`. |

Exactly one of `inventory_node_id` or `room_id` is set. Completing an enabled schedule:

- **Repeating** (`DAILY` / `WEEKLY` / `MONTHLY` / `CUSTOM_DAYS`): skip the current fire and write the next `next_fire_at`; set `last_completed_at`.
- **One-off** (`ONCE`, including refill): set `archived_at` and `enabled = false`. Archived rows are hidden from the active Schedule list.

**Delivery**

- **Android:** `flutter_local_notifications` requests `POST_NOTIFICATIONS` and owns the reminder channel (`homeventory_reminders`, labelled **Homeventory reminders**, `IMPORTANCE_HIGH` as originally shipped). After sign-in the client syncs every enabled reminder, downloads the linked **item or room photo** into app cache (subsampled, never on the UI isolate as network), and arms `AlarmManager`. Native `NotificationCompat` posts a real system notification with `DecoratedCustomViewStyle` and custom `RemoteViews`: collapsed (locale-formatted date/time, 48 dp rounded thumbnail, title, one-line item/room details) and expanded (date/time, 16:9 image card, title, details, recurrence). Bundled Poppins Regular/Medium is applied only inside those custom content views; Samsung keeps the system header (app name, shade timestamp, expand chevron). Actions **Snooze** (15 minutes, `SNOOZE_DURATION_MS`) and **Mark done** are real `NotificationCompat.Action` `PendingIntent`s. Mark done opens `MainActivity` (avoiding the Android 12 notification trampoline) and completes through `RemindersRepository`. Daily / weekly use repeating alarms; monthly / custom-interval / refill are one-shots that re-arm on fire or the next app open. Due rows `show` immediately and `notify()` the same reminder ID so image updates replace rather than duplicate. Exact-alarm permission is not required (`setAndAllowWhileIdle` / inexact repeating). Timezone ids from the OS are mapped onto the `timezone` package (GMT offsets → `Etc/GMT±N`) so a missing IANA name cannot abort scheduling. The status-bar icon is the monochrome `@drawable/ic_stat_notify`; layouts, fonts, and action receivers are kept through R8/resource shrinking. Debug builds expose **Settings → Preview reminder notification**. If the native MethodChannel is missing, the plugin falls back to BigPicture style.
- **Web / all platforms:** the Schedule tab lists, creates, edits, and turns off the same rows. Item create/edit can set a notification schedule on the object. Browser tabs do not get reliable background alarms without FCM/service workers. Due items show in the list; if the tab is open and notification permission is granted, a browser notification may fire for currently due rows.
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
- Release APKs must keep the notification drawable (`res/raw/keep.xml`), custom reminder layouts, bundled Poppins fonts, `com.dexterous.**`, and `ReminderAlarmReceiver` / `ReminderActionReceiver` ProGuard rules or alarms fail silently.
- Web has no background alarm clock.
- Refill dates move when stock or Use history changes; they are not a server job.

## Security Impact

RLS: `can_view_home` select; `can_edit_inventory` write; insert `created_by_user_id = auth.uid()`. Cross-home UUID guessing is denied like other inventory tables. Notification payloads use the reminder title/body the household already stored. Photos are copied onto the device at sync time; signed storage URLs are not sent into the notification extras.

## Database Impact

Migration: `20260826000100_reminders.sql`  
Follow-up: `20260826000200_schedule_complete_and_activity.sql` (`archived_at` / `last_completed_at`; Schedule Complete)  
Follow-up: `20260826000300_reminder_room_target.sql` (item **or** room target)

## UI Impact

- `/homes/:homeId/schedule` list + create/edit form (`/reminders` redirects here)
- Home overview tile, desktop sidebar, phone bottom-nav Schedule tab, Settings link per home
- Item create/edit: notification schedule panel; item detail: “Add to schedule”; room detail: “Add to schedule”
- Linked item **or** room is mandatory on the schedule form; refill still requires an item; active rows have a checklist **Complete** control

## References

- [`supabase/migrations/20260826000100_reminders.sql`](../../supabase/migrations/20260826000100_reminders.sql)
- [`supabase/migrations/20260826000300_reminder_room_target.sql`](../../supabase/migrations/20260826000300_reminder_room_target.sql)
- [`mobile/lib/features/reminders/`](../../mobile/lib/features/reminders/)
- [`mobile/android/app/src/main/kotlin/com/homeventory/homeventory/ReminderNotifications.kt`](../../mobile/android/app/src/main/kotlin/com/homeventory/homeventory/ReminderNotifications.kt)
- [`mobile/android/app/src/main/res/layout/notification_reminder_big.xml`](../../mobile/android/app/src/main/res/layout/notification_reminder_big.xml)
- [`mobile/android/app/src/main/res/font/poppins_regular.ttf`](../../mobile/android/app/src/main/res/font/poppins_regular.ttf)
- [`mobile/android/app/src/main/res/drawable/ic_stat_notify.xml`](../../mobile/android/app/src/main/res/drawable/ic_stat_notify.xml)
- Related: [ADR-0008](0008-inventory-transactions.md), [ADR-0001](0001-flutter-supabase-platform.md) (FCM still not runtime)
